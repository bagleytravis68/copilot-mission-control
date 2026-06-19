import { joinSession } from "@github/copilot-sdk/extension";
import { fileURLToPath } from "node:url";
import { access, mkdir, readFile, writeFile } from "node:fs/promises";
import path from "node:path";

const disabledValues = new Set(["1", "true", "yes", "on"]);
const extensionDir = path.dirname(fileURLToPath(import.meta.url));
const projectRoot = path.resolve(extensionDir, "..", "..", "..");

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

function sanitizeToolArgs(toolArgs) {
    if (!toolArgs || typeof toolArgs !== "object") {
        return null;
    }

    const keys = Object.keys(toolArgs).slice(0, 20);
    const handoffId = typeof toolArgs.handoff_id === "string" ? toolArgs.handoff_id : undefined;
    return { keys, handoffId };
}

async function readTrace(tracePath) {
    try {
        return JSON.parse(await readFile(tracePath, "utf8"));
    } catch {
        return null;
    }
}

async function recordAppEvent(input, invocation, type, details = {}) {
    const repoRoot = input?.workingDirectory ?? projectRoot;
    if (await isDisabled(repoRoot)) {
        return;
    }

    const sessionId = invocation?.sessionId ?? input?.sessionId ?? "unknown-session";
    const sessionDir = path.join(repoRoot, ".tmp", "sessions", safeSegment(sessionId));
    const tracePath = path.join(sessionDir, "app-session.json");
    const timestamp = toIso(input?.timestamp);

    await mkdir(sessionDir, { recursive: true });

    const trace = (await readTrace(tracePath)) ?? {
        schemaVersion: 1,
        harness: "github-copilot-app",
        sessionId,
        repoRoot,
        status: "running",
        startedAt: timestamp,
        endedAt: null,
        events: [],
    };

    trace.sessionId = sessionId;
    trace.repoRoot = repoRoot;

    if (type === "sessionEnd") {
        trace.status = details.reason ?? "complete";
        trace.endedAt = timestamp;
    }

    trace.events.push({
        type,
        at: timestamp,
        ...details,
    });

    await writeFile(tracePath, `${JSON.stringify(trace, null, 2)}\n`, "utf8");
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
await session.log("Mission Control app compatibility extension loaded.", { level: "info", ephemeral: true });
