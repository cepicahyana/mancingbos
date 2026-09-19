# Regenerate lib/core/indonesia_regions.dart from regencies.json
# Source: https://github.com/izzulabadi/api-wilayah-indonesia-2026
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$json = Join-Path $PSScriptRoot 'regencies.json'
if (-not (Test-Path $json)) {
  throw "Missing $json — download api/regencies.json first"
}

$regencies = Get-Content $json -Raw | ConvertFrom-Json
$provinceNames = [ordered]@{
  '11' = 'Aceh'; '12' = 'Sumatera Utara'; '13' = 'Sumatera Barat'; '14' = 'Riau'
  '15' = 'Jambi'; '16' = 'Sumatera Selatan'; '17' = 'Bengkulu'; '18' = 'Lampung'
  '19' = 'Kepulauan Bangka Belitung'; '21' = 'Kepulauan Riau'; '31' = 'DKI Jakarta'; '32' = 'Jawa Barat'
  '33' = 'Jawa Tengah'; '34' = 'DI Yogyakarta'; '35' = 'Jawa Timur'; '36' = 'Banten'
  '51' = 'Bali'; '52' = 'Nusa Tenggara Barat'; '53' = 'Nusa Tenggara Timur'
  '61' = 'Kalimantan Barat'; '62' = 'Kalimantan Tengah'; '63' = 'Kalimantan Selatan'
  '64' = 'Kalimantan Timur'; '65' = 'Kalimantan Utara'
  '71' = 'Sulawesi Utara'; '72' = 'Sulawesi Tengah'; '73' = 'Sulawesi Selatan'
  '74' = 'Sulawesi Tenggara'; '75' = 'Gorontalo'; '76' = 'Sulawesi Barat'
  '81' = 'Maluku'; '82' = 'Maluku Utara'
  '91' = 'Papua'; '92' = 'Papua Barat'; '93' = 'Papua Selatan'
  '94' = 'Papua Tengah'; '95' = 'Papua Pegunungan'; '96' = 'Papua Barat Daya'
}

function Format-CityName([string]$name) {
  $n = $name.Trim()
  if ($n -match '^(?i)Kabupaten\s+(.+)$') { return $Matches[1].Trim() }
  if ($n -match '^(?i)Kab\.\s*(.+)$') { return $Matches[1].Trim() }
  if ($n -match '^(?i)Kota\s+(.+)$') { return "Kota $($Matches[1].Trim())" }
  return $n
}

$byProv = @{}
foreach ($r in $regencies) {
  $prov = $provinceNames[$r.provinceId]
  if (-not $prov) { throw "Unknown provinceId $($r.provinceId)" }
  if (-not $byProv.ContainsKey($prov)) { $byProv[$prov] = New-Object System.Collections.Generic.List[string] }
  $byProv[$prov].Add((Format-CityName $r.name))
}

$lines = New-Object System.Collections.Generic.List[string]
$lines.Add('// Generated from api-wilayah-indonesia (514 kab/kota, 38 provinsi).')
$lines.Add('// Regenerate: powershell -File mobile/tool/gen_regions.ps1')
$lines.Add('')
$lines.Add('const indonesianProvinces = <String>[')
foreach ($p in $provinceNames.Values) { $lines.Add("  '$p',") }
$lines.Add('];')
$lines.Add('')
$lines.Add('const indonesianCitiesByProvince = <String, List<String>>{')
foreach ($p in $provinceNames.Values) {
  $lines.Add("  '$p': [")
  foreach ($c in @($byProv[$p] | Sort-Object -Unique)) {
    $lines.Add("    '$($c.Replace('\','\\').Replace('''', '\''))',")
  }
  $lines.Add('  ],')
}
$lines.Add('};')
$lines.Add('')
$lines.Add('List<String> citiesForProvince(String province) {')
$lines.Add("  if (province == 'Semua' || province.isEmpty) return const [];")
$lines.Add('  return List<String>.from(indonesianCitiesByProvince[province] ?? const <String>[]);')
$lines.Add('}')
$lines.Add('')
$lines.Add('String normalizeRegionName(String raw) {')
$lines.Add('  var s = raw.trim();')
$lines.Add("  s = s.replaceFirst(RegExp(r'^(kabupaten|kab\.?|kota)\s+', caseSensitive: false), '').trim();")
$lines.Add('  return s.toLowerCase();')
$lines.Add('}')
$lines.Add('')
$lines.Add('bool regionNameMatch(String a, String b) {')
$lines.Add('  if (a.isEmpty || b.isEmpty) return false;')
$lines.Add('  return normalizeRegionName(a) == normalizeRegionName(b);')
$lines.Add('}')

$out = Join-Path $root 'lib\core\indonesia_regions.dart'
[System.IO.File]::WriteAllLines($out, $lines)
Write-Host "OK $out ($($regencies.Count) cities)"
