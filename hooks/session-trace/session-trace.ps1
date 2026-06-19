param(
    [Parameter(Mandatory = $true)]
    [string]$Event
)

$ErrorActionPreference = "Stop"

if (
    $env:MISSION_CONTROL_DISABLED -eq "1" -or
    $env:MISSION_CONTROL_TRACE_DISABLED -eq "1" -or
    (Test-Path -LiteralPath ".\.tmp\mission-control.disabled") -or
    (Test-Path -LiteralPath ".\.tmp\mission-control-trace.disabled")
) {
    Write-Output "{}"
    exit 0
}

function ConvertTo-TraceTimestamp {
    param($Timestamp)

    if ($null -eq $Timestamp) {
        return [DateTimeOffset]::UtcNow.ToString("o")
    }

    if ($Timestamp -is [long] -or $Timestamp -is [int] -or $Timestamp -is [double]) {
        return [DateTimeOffset]::FromUnixTimeMilliseconds([int64]$Timestamp).UtcDateTime.ToString("o")
    }

    return ([DateTimeOffset]::Parse([string]$Timestamp)).UtcDateTime.ToString("o")
}

function ConvertTo-SafePathSegment {
    param([string]$Value)

    $safe = $Value -replace '[^A-Za-z0-9_.-]+', '-'
    $safe = $safe.Trim('-')
    if ([string]::IsNullOrWhiteSpace($safe)) {
        return "unknown-session"
    }

    return $safe
}

function ConvertTo-AgentKey {
    param([string]$Value)

    $safe = $Value.ToLowerInvariant() -replace '[^a-z0-9_.-]+', '-'
    $safe = $safe.Trim('-')
    if ([string]::IsNullOrWhiteSpace($safe)) {
        return "unknown-agent"
    }

    return $safe
}

function Ensure-Key {
    param(
        [hashtable]$Table,
        [string]$Key,
        $Value
    )

    if (-not $Table.ContainsKey($Key) -or $null -eq $Table[$Key]) {
        $Table[$Key] = $Value
    }
}

try {
    $raw = [Console]::In.ReadToEnd()
    if ([string]::IsNullOrWhiteSpace($raw)) {
        Write-Output "{}"
        exit 0
    }

    $payload = $raw | ConvertFrom-Json -AsHashtable -Depth 100
    $sessionId = [string]($payload.sessionId ?? $payload.session_id ?? "unknown-session")
    $repoRoot = [string]($payload.cwd ?? (Get-Location).Path)
    $at = ConvertTo-TraceTimestamp -Timestamp $payload.timestamp
    $sessionDir = Join-Path $repoRoot (Join-Path ".tmp\sessions" (ConvertTo-SafePathSegment -Value $sessionId))
    $tracePath = Join-Path $sessionDir "session.json"

    New-Item -ItemType Directory -Path $sessionDir -Force | Out-Null

    if (Test-Path -LiteralPath $tracePath) {
        $trace = Get-Content -LiteralPath $tracePath -Raw | ConvertFrom-Json -AsHashtable -Depth 100
    }
    else {
        $trace = [ordered]@{
            schemaVersion = 1
            harness = "github-copilot-cli"
            sessionId = $sessionId
            repoRoot = $repoRoot
            status = "running"
            startedAt = $at
            endedAt = $null
            agents = [ordered]@{}
            handoffs = @()
            events = @()
        }
    }

    Ensure-Key -Table $trace -Key "agents" -Value ([ordered]@{})
    Ensure-Key -Table $trace -Key "handoffs" -Value @()
    Ensure-Key -Table $trace -Key "events" -Value @()
    $trace.sessionId = $sessionId
    $trace.repoRoot = $repoRoot

    $eventRecord = [ordered]@{
        type = $Event
        at = $at
        agentName = $null
        status = $null
        reason = $null
    }

    switch ($Event) {
        "sessionStart" {
            $trace.status = "running"
            $trace.startedAt = $at
            $trace.endedAt = $null
            $eventRecord.status = "running"
            $eventRecord.reason = [string]($payload.source ?? $null)
        }
        "sessionEnd" {
            $reason = [string]($payload.reason ?? "complete")
            $trace.status = switch ($reason) {
                "complete" { "complete" }
                "error" { "error" }
                "timeout" { "timeout" }
                "abort" { "aborted" }
                "user_exit" { "user_exit" }
                default { "complete" }
            }
            $trace.endedAt = $at
            $eventRecord.status = $trace.status
            $eventRecord.reason = $reason
        }
        "subagentStart" {
            $agentName = [string]($payload.agentName ?? $payload.agent_name ?? "unknown-agent")
            $agentKey = ConvertTo-AgentKey -Value $agentName
            $trace.agents[$agentKey] = [ordered]@{
                name = $agentName
                displayName = ($payload.agentDisplayName ?? $payload.agent_display_name ?? $null)
                description = ($payload.agentDescription ?? $null)
                status = "running"
                startedAt = $at
                completedAt = $null
                handoffIds = @()
            }
            $eventRecord.agentName = $agentName
            $eventRecord.status = "running"
        }
        "subagentStop" {
            $agentName = [string]($payload.agentName ?? $payload.agent_name ?? "unknown-agent")
            $agentKey = ConvertTo-AgentKey -Value $agentName
            if (-not $trace.agents.ContainsKey($agentKey)) {
                $trace.agents[$agentKey] = [ordered]@{
                    name = $agentName
                    displayName = ($payload.agentDisplayName ?? $payload.agent_display_name ?? $null)
                    description = $null
                    status = "running"
                    startedAt = $at
                    completedAt = $null
                    handoffIds = @()
                }
            }

            $trace.agents[$agentKey].status = "complete"
            $trace.agents[$agentKey].completedAt = $at
            $eventRecord.agentName = $agentName
            $eventRecord.status = "complete"
            $eventRecord.reason = [string]($payload.stopReason ?? $payload.stop_reason ?? $null)
        }
    }

    $trace.events = @($trace.events) + $eventRecord
    $trace | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $tracePath -Encoding utf8
}
catch {
    [Console]::Error.WriteLine("Mission Control session trace hook skipped: $($_.Exception.Message)")
}

Write-Output "{}"
