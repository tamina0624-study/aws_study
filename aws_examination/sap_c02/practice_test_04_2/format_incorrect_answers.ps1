$ErrorActionPreference = 'Stop'

$sourcePath = Join-Path $PSScriptRoot 'incorrect_answers_raw.txt'
$outputPath = Join-Path $PSScriptRoot 'incorrect_answers_formatted.txt'
$lines = Get-Content -Encoding UTF8 -LiteralPath $sourcePath

$titles = @{
    '11' = 'Direct ConnectとS3インターフェースエンドポイントによるプライベート接続'
    '16' = 'ENIとParameter Storeを使用したレガシーアプリケーションの高可用性'
    '19' = 'CodeDeployとAuto Scalingによるデプロイ自動化'
    '25' = 'マルチリージョンAPIのアクティブアクティブ構成'
}

function Convert-Text([string]$text) {
    $text = $text -replace ' ', '_'
    $text = $text -replace ',', '、'
    $text = $text -replace '"', '”'
    $text = $text -replace '「', '{'
    $text = $text -replace '」', '}'
    $text = $text -replace '@', '＠'
    return $text
}

$starts = for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match '^問題(\d+):$') { $i }
}

$results = for ($blockIndex = 0; $blockIndex -lt $starts.Count; $blockIndex++) {
    $start = $starts[$blockIndex]
    $end = if ($blockIndex + 1 -lt $starts.Count) { $starts[$blockIndex + 1] - 1 } else { $lines.Count - 1 }
    $block = @($lines[$start..$end])
    $number = [regex]::Match($block[0], '\d+').Value

    $overallIndex = [Array]::IndexOf($block, '全体的な説明')
    $referenceIndex = [Array]::IndexOf($block, '参考資料')
    if ($overallIndex -lt 0) { throw "問題$number に「全体的な説明」がありません。" }
    if ($referenceIndex -lt 0) { $referenceIndex = $block.Count }

    $optionRows = [System.Collections.Generic.List[object]]::new()
    for ($i = 1; $i -lt $overallIndex; $i++) {
        if ($block[$i] -ne '説明') { continue }
        $previous = $i - 1
        while ($previous -ge 1 -and [string]::IsNullOrWhiteSpace($block[$previous])) { $previous-- }
        if ($previous -lt 1) { continue }
        $optionRows.Add([pscustomobject]@{ Index = $previous; Text = $block[$previous] })
    }
    if ($optionRows.Count -eq 0) { throw "問題$number の選択肢を抽出できません。" }

    $questionEnd = $optionRows[0].Index - 1
    while ($questionEnd -ge 1 -and ([string]::IsNullOrWhiteSpace($block[$questionEnd]) -or $block[$questionEnd] -in @('正解', '不正解', '選択は正解です', '選択は不正解です', '正しい選択', '回答は正解です', '回答は不正解です'))) { $questionEnd-- }
    $questionLines = @($block[1..$questionEnd])
    while ($questionLines.Count -gt 0 -and [string]::IsNullOrWhiteSpace($questionLines[-1])) { $questionLines = @($questionLines[0..($questionLines.Count - 2)]) }
    $question = ($questionLines | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }) -join '</br>'

    $options = [System.Collections.Generic.List[string]]::new()
    $correctLetters = [System.Collections.Generic.List[string]]::new()
    foreach ($row in $optionRows) {
        $letter = [char]([int][char]'A' + $options.Count)
        $options.Add("${letter}:_$($row.Text)")
        $explanationIndex = $row.Index + 1
        while ($explanationIndex -lt $overallIndex -and $block[$explanationIndex] -ne '説明') { $explanationIndex++ }
        $answerIndex = $explanationIndex + 1
        while ($answerIndex -lt $overallIndex -and [string]::IsNullOrWhiteSpace($block[$answerIndex])) { $answerIndex++ }
        if ($answerIndex -lt $overallIndex -and $block[$answerIndex] -match '^正解(?:\s|$)') { $correctLetters.Add([string]$letter) }
    }

    $explanationLines = if ($referenceIndex -gt $overallIndex + 1) { @($block[($overallIndex + 1)..($referenceIndex - 1)]) } else { @() }
    while ($explanationLines.Count -gt 0 -and [string]::IsNullOrWhiteSpace($explanationLines[0])) { $explanationLines = @($explanationLines[1..($explanationLines.Count - 1)]) }
    while ($explanationLines.Count -gt 0 -and [string]::IsNullOrWhiteSpace($explanationLines[-1])) { $explanationLines = @($explanationLines[0..($explanationLines.Count - 2)]) }
    $explanation = ($explanationLines | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }) -join '</br>'

    $answer = $correctLetters -join '、'
    $record = "★★【問題${number}：$($titles[$number])】</br>問題文:</br>${question}</br></br>選択肢:</br>$($options -join '</br>')☆☆解答・解説:</br>正解：${answer}</br></br>【全体的な説明】</br>${explanation}"
    'test3_' + ((Convert-Text $record) -replace '☆☆解答・解説', ',☆☆解答・解説')
}

[IO.File]::WriteAllLines($outputPath, $results, [Text.UTF8Encoding]::new($false))
Write-Output $outputPath
