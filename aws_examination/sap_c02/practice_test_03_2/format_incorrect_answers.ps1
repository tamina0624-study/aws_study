$ErrorActionPreference = 'Stop'

$sourcePath = Join-Path $PSScriptRoot 'incorrect_answers_raw.txt'
$outputPath = Join-Path $PSScriptRoot 'incorrect_answers_formatted.txt'
$lines = Get-Content -Encoding UTF8 -LiteralPath $sourcePath

$titles = @{
    '24' = 'Snowball EdgeとDMSによる大容量データベース移行'
    '58' = 'DynamoDBのコスト最適化'
    '59' = 'AWS Organizationsの一括請求とRI割引共有'
    '61' = 'EBSスナップショットのクロスリージョンDR'
    '74' = 'Storage Gatewayによるファイル共有移行'
    '75' = 'ECS Fargateのブルーグリーンデプロイとスケーリング'
}

$questionOverrides = @{
    '59' = 'ある企業では、複数のチームがそれぞれ別のAWSアカウントを使用しています。すべてのチームは同じAWSリージョンで作業しており、各チームのAWSリソースを、オンプレミスネットワークに接続された1つの共通VPC内に配置したいと考えています。</br>オンプレミスネットワークとAWS間の総トラフィックは50Mbps未満です。</br>複数のAWSアカウントで1つのVPCを共有し、オンプレミスとの接続も提供する構成を、最も低いコストで実現するにはどうすればよいですか？_2つ選択してください。'
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
    if ($lines[$i] -match '^問題(\d+)$') { $i }
}

$results = for ($blockIndex = 0; $blockIndex -lt $starts.Count; $blockIndex++) {
    $start = $starts[$blockIndex]
    $end = if ($blockIndex + 1 -lt $starts.Count) { $starts[$blockIndex + 1] - 1 } else { $lines.Count - 1 }
    $block = @($lines[$start..$end])
    $number = [regex]::Match($block[0], '\d+').Value

    $firstBlank = 2
    while ($firstBlank -lt $block.Count -and $block[$firstBlank] -ne '') { $firstBlank++ }
    $question = ($block[2..($firstBlank - 1)] -join '</br>')
    if ($questionOverrides.ContainsKey($number)) { $question = $questionOverrides[$number] }

    $overallIndex = [Array]::IndexOf($block, '全体的な説明')
    $referenceIndex = [Array]::IndexOf($block, '参考資料')
    if ($overallIndex -lt 0) { throw "問題$number に「全体的な説明」がありません。" }
    if ($referenceIndex -lt 0) { $referenceIndex = $block.Count }

    $options = [System.Collections.Generic.List[string]]::new()
    $correctLetters = [System.Collections.Generic.List[string]]::new()
    for ($i = $firstBlank + 1; $i -lt $overallIndex; $i++) {
        if ($block[$i] -ne '説明') { continue }
        $previous = $i - 1
        while ($previous -ge 0 -and [string]::IsNullOrWhiteSpace($block[$previous])) { $previous-- }
        if ($previous -lt 0) { continue }
        $optionText = $block[$previous]
        if ($optionText -in @('正解', '不正解', '回答は正解です', '回答は不正解です')) { continue }
        $letter = [char]([int][char]'A' + $options.Count)
        $options.Add("${letter}:_$optionText")

        $next = $i + 1
        while ($next -lt $overallIndex -and [string]::IsNullOrWhiteSpace($block[$next])) { $next++ }
        if ($next -lt $overallIndex -and $block[$next] -match '^正解(?:\s|$)') { $correctLetters.Add([string]$letter) }
    }

    $explanationLines = if ($referenceIndex -gt $overallIndex + 1) {
        @($block[($overallIndex + 1)..($referenceIndex - 1)])
    } else { @() }
    while ($explanationLines.Count -gt 0 -and [string]::IsNullOrWhiteSpace($explanationLines[0])) {
        $explanationLines = @($explanationLines[1..($explanationLines.Count - 1)])
    }
    while ($explanationLines.Count -gt 0 -and [string]::IsNullOrWhiteSpace($explanationLines[-1])) {
        $explanationLines = @($explanationLines[0..($explanationLines.Count - 2)])
    }
    $explanation = ($explanationLines -join '</br>')

    $title = $titles[$number]
    if (-not $title) { $title = "AWS認定試験問題$number" }
    $answer = $correctLetters -join '、'
    $record = "★★【問題${number}：${title}】</br>問題文:</br>${question}</br></br>選択肢:</br>$($options -join '</br>')、☆☆解答・解説:</br>正解：${answer}</br></br>【全体的な説明】</br>${explanation}"
    'test3_' + (Convert-Text $record)
}

[IO.File]::WriteAllLines($outputPath, $results, [Text.UTF8Encoding]::new($false))
Write-Output $outputPath


