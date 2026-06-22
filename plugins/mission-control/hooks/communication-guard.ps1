param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("preToolUse", "subagentStart", "subagentStop")]
    [string]$Event
)

$ErrorActionPreference = "Stop"

if (
    $env:MISSION_CONTROL_DISABLED -eq "1" -or
    $env:MISSION_CONTROL_GUARD_DISABLED -eq "1" -or
    (Test-Path -LiteralPath ".\.tmp\mission-control.disabled") -or
    (Test-Path -LiteralPath ".\.tmp\mission-control-guard.disabled")
) {
    Write-Output "{}"
    exit 0
}

$missionAgentPatterns = @(
    "maestro", "maestro-orchestrator", "maestro \(orchestrator\)", "mission-control-agent-team:maestro-orchestrator",
    "pax", "pax-planner", "pax \(planner\)", "mission-control-agent-team:pax-planner",
    "scout", "scout-explorer", "scout \(explorer\)", "mission-control-agent-team:scout-explorer",
    "ava", "ava-architect", "ava \(architect\)", "mission-control-agent-team:ava-architect",
    "carl", "carl-coder", "carl \(coder\)", "mission-control-agent-team:carl-coder",
    "tess", "tess-tester", "tess \(tester\)", "mission-control-agent-team:tess-tester",
    "sera", "sera-security", "sera \(security\)", "mission-control-agent-team:sera-security",
    "riley", "riley-relay", "riley \(relay\)", "mission-control-agent-team:riley-relay",
    "sam", "sam-scribe", "sam \(scribe\)", "mission-control-agent-team:sam-scribe",
    "libby", "libby-librarian", "libby \(librarian\)", "mission-control-agent-team:libby-librarian"
)

function Test-MissionAgentText {
    param([string]$Text)

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return $false
    }

    $normalized = $Text.ToLowerInvariant()
    foreach ($pattern in $missionAgentPatterns) {
        if ($normalized -match "(?<![a-z0-9_-])$pattern(?![a-z0-9_-])") {
            return $true
        }
    }

    return $false
}

function Get-Strings {
    param($Value)

    $strings = @()
    if ($null -eq $Value) {
        return $strings
    }

    if ($Value -is [string]) {
        return @($Value)
    }

    if ($Value -is [System.Collections.IDictionary]) {
        foreach ($key in $Value.Keys) {
            $strings += Get-Strings -Value $Value[$key]
        }
        return $strings
    }

    if ($Value -is [System.Collections.IEnumerable]) {
        foreach ($item in $Value) {
            $strings += Get-Strings -Value $item
        }
    }

    return $strings
}

function ConvertTo-GuardHashtable {
    param($Value)

    if ($null -eq $Value) {
        return $null
    }

    if ($Value -is [System.Collections.IDictionary]) {
        $table = @{}
        foreach ($key in $Value.Keys) {
            $table[$key] = ConvertTo-GuardHashtable -Value $Value[$key]
        }
        return $table
    }

    if ($Value -is [System.Management.Automation.PSCustomObject]) {
        $table = @{}
        foreach ($property in $Value.PSObject.Properties) {
            $table[$property.Name] = ConvertTo-GuardHashtable -Value $property.Value
        }
        return $table
    }

    if ($Value -is [System.Collections.IEnumerable] -and $Value -isnot [string]) {
        $items = @()
        foreach ($item in $Value) {
            $items += ,(ConvertTo-GuardHashtable -Value $item)
        }
        return ,$items
    }

    return $Value
}

function Get-FirstValue {
    param(
        [System.Collections.IDictionary]$Object,
        [string[]]$Names,
        $Default = $null
    )

    foreach ($name in $Names) {
        if ($Object.ContainsKey($name) -and $null -ne $Object[$name]) {
            return $Object[$name]
        }
    }

    return $Default
}

function Test-MissionControlRequest {
    param(
        $ToolArgs,
        [array]$JsonObjects,
        [string]$CombinedText
    )

    foreach ($object in $JsonObjects) {
        if ($object.ContainsKey("to") -and (Test-MissionAgentText -Text ([string]$object.to))) {
            return $true
        }
    }

    if ($ToolArgs -is [System.Collections.IDictionary]) {
        foreach ($field in @("to", "agent", "agentName", "agent_name", "name", "subagent", "target", "targetAgent", "target_agent")) {
            if ($ToolArgs.ContainsKey($field) -and (Test-MissionAgentText -Text ([string]$ToolArgs[$field]))) {
                return $true
            }
        }
    }

    return Test-MissionAgentText -Text $CombinedText
}

function Get-JsonObjectsFromText {
    param([string]$Text)

    $objects = @()
    if ([string]::IsNullOrWhiteSpace($Text)) {
        return $objects
    }

    for ($start = 0; $start -lt $Text.Length; $start++) {
        if ($Text[$start] -ne "{") {
            continue
        }

        $depth = 0
        $inString = $false
        $escaped = $false
        for ($index = $start; $index -lt $Text.Length; $index++) {
            $char = $Text[$index]
            if ($inString) {
                if ($escaped) {
                    $escaped = $false
                }
                elseif ($char -eq "\") {
                    $escaped = $true
                }
                elseif ($char -eq '"') {
                    $inString = $false
                }
                continue
            }

            if ($char -eq '"') {
                $inString = $true
            }
            elseif ($char -eq "{") {
                $depth++
            }
            elseif ($char -eq "}") {
                $depth--
                if ($depth -eq 0) {
                    $candidate = $Text.Substring($start, $index - $start + 1)
                    try {
                        $objects += ,(ConvertTo-GuardHashtable -Value ($candidate | ConvertFrom-Json))
                    }
                    catch {
                    }
                    break
                }
            }
        }
    }

    return $objects
}

function Test-StringList {
    param(
        $Value,
        [string]$Name,
        [System.Collections.Generic.List[string]]$Errors
    )

    if ($Value -isnot [System.Collections.IEnumerable] -or $Value -is [string]) {
        $Errors.Add("$Name must be an array of short strings.")
        return
    }

    $count = 0
    foreach ($item in $Value) {
        $count++
        if ($item -isnot [string] -or [string]::IsNullOrWhiteSpace($item)) {
            $Errors.Add("$Name entries must be non-empty strings.")
        }
    }

    if ($count -gt 12) {
        $Errors.Add("$Name must contain 12 or fewer entries.")
    }
}

function Test-HandoffRequest {
    param($Object)

    $errors = [System.Collections.Generic.List[string]]::new()
    foreach ($field in @("handoff_id", "to", "goal", "scope", "constraints", "success", "deliverable")) {
        if (-not $Object.ContainsKey($field)) {
            $errors.Add("Missing request field: $field.")
        }
    }

    foreach ($field in @("handoff_id", "to", "goal", "deliverable")) {
        if ($Object.ContainsKey($field) -and ($Object[$field] -isnot [string] -or [string]::IsNullOrWhiteSpace($Object[$field]))) {
            $errors.Add("$field must be a non-empty string.")
        }
    }

    foreach ($field in @("scope", "constraints", "success")) {
        if ($Object.ContainsKey($field)) {
            Test-StringList -Value $Object[$field] -Name $field -Errors $errors
        }
    }

    foreach ($field in $Object.Keys) {
        if (@("handoff_id", "to", "goal", "scope", "constraints", "success", "deliverable", "custom") -notcontains $field) {
            $errors.Add("Unknown request field: $field.")
        }
    }

    return $errors
}

function Test-HandoffResponse {
    param($Object)

    $errors = [System.Collections.Generic.List[string]]::new()
    foreach ($field in @("handoff_id", "status", "summary", "evidence", "artifacts", "gaps", "next")) {
        if (-not $Object.ContainsKey($field)) {
            $errors.Add("Missing response field: $field.")
        }
    }

    if ($Object.ContainsKey("status") -and @("SUCCESS", "PARTIAL", "FAILED", "BLOCKED") -notcontains $Object.status) {
        $errors.Add("status must be SUCCESS, PARTIAL, FAILED, or BLOCKED.")
    }

    foreach ($field in @("handoff_id", "summary")) {
        if ($Object.ContainsKey($field) -and ($Object[$field] -isnot [string] -or [string]::IsNullOrWhiteSpace($Object[$field]))) {
            $errors.Add("$field must be a non-empty string.")
        }
    }

    foreach ($field in @("evidence", "artifacts")) {
        if ($Object.ContainsKey($field)) {
            Test-StringList -Value $Object[$field] -Name $field -Errors $errors
        }
    }

    foreach ($field in $Object.Keys) {
        if (@("handoff_id", "status", "summary", "evidence", "artifacts", "gaps", "next", "custom") -notcontains $field) {
            $errors.Add("Unknown response field: $field.")
        }
    }

    return $errors
}

function Get-WrapperInstruction {
    return "Mission Control communication wrapper required. Request JSON: {`"handoff_id`":`"...`",`"to`":`"agent`",`"goal`":`"one sentence`",`"scope`":[`"paths/systems`"],`"constraints`":[`"hard limits`"],`"success`":[`"measurable result`"],`"deliverable`":`"expected output`"}. Response JSON only: {`"handoff_id`":`"same`",`"status`":`"SUCCESS|PARTIAL|FAILED|BLOCKED`",`"summary`":`"1-2 sentences`",`"evidence`":[`"commands/files/facts`"],`"artifacts`":[`"paths`"],`"gaps`":null,`"next`":null,`"custom`":{}}. Keep it concise; do not include prompt text, secrets, or tool output dumps."
}

try {
    $raw = [Console]::In.ReadToEnd()
    if ([string]::IsNullOrWhiteSpace($raw)) {
        Write-Output "{}"
        exit 0
    }

    $payload = ConvertTo-GuardHashtable -Value ($raw | ConvertFrom-Json)

    if ($Event -eq "subagentStart") {
        $agentName = [string](Get-FirstValue -Object $payload -Names @("agentName", "agent_name") -Default "")
        if (Test-MissionAgentText -Text $agentName) {
            @{ additionalContext = Get-WrapperInstruction } | ConvertTo-Json -Compress
            exit 0
        }
    }

    if ($Event -eq "preToolUse") {
        $toolName = [string](Get-FirstValue -Object $payload -Names @("toolName", "tool_name") -Default "")
        if ($toolName -notmatch "^(agent|task)$") {
            Write-Output "{}"
            exit 0
        }

        $toolArgs = Get-FirstValue -Object $payload -Names @("toolArgs", "tool_input")
        $strings = Get-Strings -Value $toolArgs
        $combined = ($strings -join "`n")
        $objects = Get-JsonObjectsFromText -Text $combined
        if (-not (Test-MissionControlRequest -ToolArgs $toolArgs -JsonObjects $objects -CombinedText $combined)) {
            Write-Output "{}"
            exit 0
        }

        $request = $objects | Where-Object { $_.ContainsKey("handoff_id") } | Select-Object -First 1
        if ($null -eq $request) {
            @{
                permissionDecision = "deny"
                permissionDecisionReason = "Mission Control subagent handoffs must include the compact JSON request wrapper with handoff_id, to, goal, scope, constraints, success, and deliverable."
            } | ConvertTo-Json -Compress
            exit 0
        }

        $errors = Test-HandoffRequest -Object $request
        if ($errors.Count -gt 0) {
            @{
                permissionDecision = "deny"
                permissionDecisionReason = "Invalid Mission Control handoff request: $($errors -join ' ')"
            } | ConvertTo-Json -Compress
            exit 0
        }
    }

    if ($Event -eq "subagentStop") {
        $agentName = [string](Get-FirstValue -Object $payload -Names @("agentName", "agent_name") -Default "")
        if (-not (Test-MissionAgentText -Text $agentName)) {
            Write-Output "{}"
            exit 0
        }

        $transcriptPath = [string](Get-FirstValue -Object $payload -Names @("transcriptPath", "transcript_path") -Default "")
        if (-not (Test-Path -LiteralPath $transcriptPath)) {
            Write-Output "{}"
            exit 0
        }

        $text = Get-Content -LiteralPath $transcriptPath -Raw
        if ($text.Length -gt 200000) {
            $text = $text.Substring($text.Length - 200000)
        }

        $objects = Get-JsonObjectsFromText -Text $text
        $responses = @($objects | Where-Object { $_.ContainsKey("handoff_id") -and $_.ContainsKey("status") })
        $response = $responses | Select-Object -Last 1
        if ($null -eq $response) {
            @{
                decision = "block"
                reason = "Return the Mission Control response wrapper as JSON only: handoff_id, status, summary, evidence, artifacts, gaps, next, optional custom."
            } | ConvertTo-Json -Compress
            exit 0
        }

        $errors = Test-HandoffResponse -Object $response
        if ($errors.Count -gt 0) {
            @{
                decision = "block"
                reason = "Fix the Mission Control response wrapper: $($errors -join ' ') Return JSON only."
            } | ConvertTo-Json -Compress
            exit 0
        }
    }
}
catch {
    [Console]::Error.WriteLine("Mission Control communication guard skipped: $($_.Exception.Message)")
}

Write-Output "{}"
