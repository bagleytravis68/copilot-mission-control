import { joinSession } from "@github/copilot-sdk/extension";
import { fileURLToPath } from "node:url";
import { access, mkdir, readFile, rename, writeFile } from "node:fs/promises";
import path from "node:path";

const disabledValues = new Set(["1", "true", "yes", "on"]);
const extensionDir = path.dirname(fileURLToPath(import.meta.url));
const projectRoot = path.resolve(extensionDir, "..", "..", "..");
const traceQueues = new Map();
let traceWriteSequence = 0;

async function fileExists(filePath) {
    try {
        await access(filePath);
        return true;
    } catch {
        return false;
    }
}

async function isDisabled(repoRoot) {
    return (
        disabledValues.has(String(process.env.MISSION_CONTROL_DISABLED ?? "").toLowerCase()) ||
        disabledValues.has(String(process.env.MISSION_CONTROL_TRACE_DISABLED ?? "").toLowerCase()) ||
        await fileExists(path.join(repoRoot, ".tmp", "mission-control.disabled")) ||
        await fileExists(path.join(repoRoot, ".tmp", "mission-control-trace.disabled"))
    );
}

function safeSegment(value, fallback = "unknown-session") {
    const safe = String(value ?? "").replace(/[^A-Za-z0-9_.-]+/g, "-").replace(/^-+|-+$/g, "");
    return safe || fallback;
}

function toIso(value) {
    if (!value) {
        return new Date().toISOString();
    }

    return new Date(value).toISOString();
}

function toTraceStatus(status) {
    switch (status) {
        case "complete":
        case "error":
        case "timeout":
        case "user_exit":
        case "running":
            return status;
        case "abort":
            return "aborted";
        case "failed":
            return "error";
        default:
            return "complete";
    }
}

function sleep(ms) {
    return new Promise((resolve) => setTimeout(resolve, ms));
}

function sanitizeToolArgs(toolArgs) {
    if (!toolArgs || typeof toolArgs !== "object") {
        return null;
    }

    const keys = Object.keys(toolArgs).slice(0, 20);
    const handoffId = typeof toolArgs.handoff_id === "string" ? toolArgs.handoff_id : undefined;
    const requestedModel = typeof toolArgs.model === "string" ? toolArgs.model : undefined;
    const agentType = typeof toolArgs.agent_type === "string" ? toolArgs.agent_type : undefined;
    const agentName = typeof toolArgs.name === "string" ? toolArgs.name : undefined;
    const mode = typeof toolArgs.mode === "string" ? toolArgs.mode : undefined;
    return { keys, handoffId, requestedModel, agentType, agentName, mode };
}

function sanitizeSessionEvent(event) {
    const data = event?.data ?? {};
    const record = {
        sdkEventType: event?.type,
        eventId: typeof event?.id === "string" ? event.id : undefined,
        parentEventId: typeof event?.parentId === "string" ? event.parentId : event?.parentId === null ? null : undefined,
        agentId: typeof event?.agentId === "string" ? event.agentId : undefined,
        ephemeral: typeof event?.ephemeral === "boolean" ? event.ephemeral : undefined,
    };

    switch (event?.type) {
        case "session.start":
        case "session.resume":
            return {
                ...record,
                status: "running",
                model: data.selectedModel,
                reasoningEffort: data.reasoningEffort,
                contextTier: data.contextTier,
                copilotVersion: data.copilotVersion,
                producer: data.producer,
                branch: data.context?.git?.branch ?? data.context?.branch,
            };
        case "session.model_change":
            return {
                ...record,
                previousModel: data.previousModel,
                model: data.newModel,
                reasoningEffort: data.reasoningEffort,
                contextTier: data.contextTier,
                reason: data.cause,
            };
        case "subagent.started":
        case "subagent.completed":
        case "subagent.failed":
            return {
                ...record,
                agentName: data.agentName,
                agentDisplayName: data.agentDisplayName,
                agentDescription: data.agentDescription,
                model: data.model,
                toolCallId: data.toolCallId,
                status: event.type === "subagent.started" ? "running" : event.type === "subagent.completed" ? "complete" : "failed",
                durationMs: data.durationMs,
                totalTokens: data.totalTokens,
                totalToolCalls: data.totalToolCalls,
                errorLength: typeof data.errorMessage === "string" ? data.errorMessage.length : undefined,
            };
        case "subagent.selected":
            return {
                ...record,
                agentName: data.agentName,
                agentDisplayName: data.agentDisplayName,
                toolNames: Array.isArray(data.tools) ? data.tools.slice(0, 50) : data.tools,
            };
        case "subagent.deselected":
            return record;
        case "assistant.usage":
            return {
                ...record,
                model: data.model,
                initiator: data.initiator,
                inputTokens: data.inputTokens,
                outputTokens: data.outputTokens,
                reasoningTokens: data.reasoningTokens,
                cacheReadTokens: data.cacheReadTokens,
                cacheWriteTokens: data.cacheWriteTokens,
                finishReason: data.finishReason,
                durationMs: data.duration,
                apiEndpoint: data.apiEndpoint,
            };
        case "assistant.message":
            return {
                ...record,
                model: data.model,
                messageId: data.messageId,
                turnId: data.turnId,
                outputTokens: data.outputTokens,
                contentLength: typeof data.content === "string" ? data.content.length : undefined,
                toolRequestCount: Array.isArray(data.toolRequests) ? data.toolRequests.length : undefined,
            };
        case "assistant.turn_start":
            return {
                ...record,
                turnId: data.turnId,
            };
        case "tool.execution_start":
            return {
                ...record,
                model: data.model,
                toolCallId: data.toolCallId,
                toolName: data.toolName,
                turnId: data.turnId,
                parentToolCallId: data.parentToolCallId,
                toolArgs: sanitizeToolArgs(data.arguments),
            };
        case "tool.execution_complete":
            return {
                ...record,
                model: data.model,
                toolCallId: data.toolCallId,
                toolName: data.toolName,
                turnId: data.turnId,
                parentToolCallId: data.parentToolCallId,
                status: data.success === true ? "complete" : "failed",
                resultType: data.success === true ? "success" : data.error?.code ?? "failure",
                sandboxed: data.sandboxed,
            };
        case "skill.invoked":
            return {
                ...record,
                skillName: data.name,
                source: data.source,
                trigger: data.trigger,
                pluginName: data.pluginName,
                pluginVersion: data.pluginVersion,
                allowedToolsCount: Array.isArray(data.allowedTools) ? data.allowedTools.length : undefined,
            };
        case "model.call_failure":
            return {
                ...record,
                model: data.model,
                initiator: data.initiator,
                status: "failed",
                statusCode: data.statusCode,
                durationMs: data.durationMs,
                source: data.source,
                errorLength: typeof data.errorMessage === "string" ? data.errorMessage.length : undefined,
            };
        default:
            return record;
    }
}

async function readTrace(tracePath) {
    for (let attempt = 0; attempt < 3; attempt += 1) {
        try {
            return JSON.parse(await readFile(tracePath, "utf8"));
        } catch {
            if (!await fileExists(tracePath)) {
                return null;
            }
            await sleep(50);
        }
    }

    return undefined;
}

async function writeTrace(tracePath, trace) {
    traceWriteSequence += 1;
    const tempPath = `${tracePath}.${process.pid}.${Date.now()}.${traceWriteSequence}.tmp`;
    await writeFile(tempPath, `${JSON.stringify(trace, null, 2)}\n`, "utf8");
    await rename(tempPath, tracePath);
}

async function updateTrace(tracePath, updater) {
    const previous = traceQueues.get(tracePath) ?? Promise.resolve();
    const next = previous.catch(() => {}).then(updater);
    traceQueues.set(tracePath, next);

    try {
        return await next;
    } finally {
        if (traceQueues.get(tracePath) === next) {
            traceQueues.delete(tracePath);
        }
    }
}

async function recordAppEvent(input, invocation, type, details = {}) {
    const repoRoot = input?.workingDirectory ?? projectRoot;
    if (await isDisabled(repoRoot)) {
        return;
    }

    const sessionId = invocation?.sessionId ?? input?.sessionId ?? "unknown-session";
    const sessionDir = path.join(repoRoot, ".tmp", "sessions", safeSegment(sessionId));
    const tracePath = path.join(sessionDir, "session.json");
    const timestamp = toIso(input?.timestamp);

    await mkdir(sessionDir, { recursive: true });

    await updateTrace(tracePath, async () => {
        const existingTrace = await readTrace(tracePath);
        if (existingTrace === undefined) {
            return;
        }

        const trace = existingTrace ?? {
            schemaVersion: 1,
            harness: "github-copilot-app",
            sessionId,
            repoRoot,
            status: "running",
            startedAt: timestamp,
            endedAt: null,
            agents: {},
            handoffs: [],
            events: [],
        };

        trace.harness = trace.harness === "github-copilot-cli" ? "multi" : trace.harness;
        trace.sessionId = sessionId;
        trace.repoRoot = repoRoot;
        trace.agents ??= {};
        trace.handoffs ??= [];
        trace.events ??= [];

        if (type === "sessionEnd") {
            trace.status = toTraceStatus(details.reason);
            trace.endedAt = timestamp;
        }
        if (details.status === "running") {
            trace.status = "running";
            trace.endedAt = null;
        }

        const agentName = typeof details.agentName === "string" ? details.agentName : null;
        if (agentName) {
            const agentKey = safeSegment(agentName.toLowerCase(), "unknown-agent");
            const existing = trace.agents[agentKey] ?? {};
            trace.agents[agentKey] = {
                name: agentName,
                displayName: details.agentDisplayName ?? existing.displayName ?? null,
                description: details.agentDescription ?? existing.description ?? null,
                status: details.status === "complete" || details.status === "failed" ? details.status : existing.status ?? details.status ?? "running",
                startedAt: existing.startedAt ?? timestamp,
                completedAt: details.status === "complete" || details.status === "failed" ? timestamp : existing.completedAt ?? null,
                handoffIds: existing.handoffIds ?? [],
                model: details.model ?? existing.model ?? null,
                agentId: details.agentId ?? existing.agentId ?? null,
                toolCallId: details.toolCallId ?? existing.toolCallId ?? null,
            };
        }

        trace.events.push({
            type,
            at: timestamp,
            eventSource: "copilot-app-extension",
            ...details,
        });

        await writeTrace(tracePath, trace);
    });
}

async function recordSessionEvent(event) {
    await recordAppEvent(
        { workingDirectory: projectRoot, timestamp: event?.timestamp },
        { sessionId: session.sessionId },
        event?.type ?? "session.event",
        sanitizeSessionEvent(event),
    );
}

const session = await joinSession({
    hooks: {
        onSessionStart: async (input, invocation) => {
            await recordAppEvent(input, invocation, "sessionStart", { source: input.source });
        },
        onSessionEnd: async (input, invocation) => {
            await recordAppEvent(input, invocation, "sessionEnd", { reason: input.reason });
        },
        onUserPromptSubmitted: async (input, invocation) => {
            await recordAppEvent(input, invocation, "userPromptSubmitted", {
                promptLength: typeof input.prompt === "string" ? input.prompt.length : 0,
            });
        },
        onPreToolUse: async (input, invocation) => {
            await recordAppEvent(input, invocation, "preToolUse", {
                toolName: input.toolName,
                toolArgs: sanitizeToolArgs(input.toolArgs),
            });
        },
        onPreMcpToolCall: async (input, invocation) => {
            await recordAppEvent(input, invocation, "preMcpToolCall", {
                serverName: input.serverName,
                toolName: input.toolName,
                toolCallId: input.toolCallId,
                toolArgs: sanitizeToolArgs(input.arguments),
            });
        },
        onPostToolUse: async (input, invocation) => {
            await recordAppEvent(input, invocation, "postToolUse", {
                toolName: input.toolName,
                resultType: input.toolResult?.resultType ?? "success",
            });
        },
        onPostToolUseFailure: async (input, invocation) => {
            await recordAppEvent(input, invocation, "postToolUseFailure", {
                toolName: input.toolName,
                errorLength: typeof input.error === "string" ? input.error.length : 0,
            });
        },
        onErrorOccurred: async (input, invocation) => {
            await recordAppEvent(input, invocation, "errorOccurred", {
                errorContext: input.errorContext,
                recoverable: input.recoverable,
            });
        },
    },
});

await recordAppEvent({ workingDirectory: projectRoot, timestamp: new Date() }, { sessionId: session.sessionId }, "extensionAttached");

for (const eventType of [
    "session.start",
    "session.resume",
    "session.model_change",
    "subagent.started",
    "subagent.completed",
    "subagent.failed",
    "subagent.selected",
    "subagent.deselected",
    "assistant.usage",
    "assistant.message",
    "assistant.turn_start",
    "tool.execution_start",
    "tool.execution_complete",
    "skill.invoked",
    "model.call_failure",
]) {
    session.on(eventType, recordSessionEvent);
}

await session.log("Mission Control app compatibility extension loaded.", { level: "info", ephemeral: true });
