# Update app
yt-dlp -U

# Replace with your YouTube playlist URL
$playlistUrl = Read-Host "Enter the playlist URL"

# Directory to save the downloaded videos
$output_dir = "$env:userprofile\Desktop\YouTube"
#$output_dir = "G:\YouTube"

# Create the output directory if it doesn't exist
New-Item -ItemType Directory -Path $output_dir | Out-Null

# Download the playlist
#yt-dlp -o "$output_dir/%(title)s.%(ext)s" --extract-audio --audio-format mp3 $playlistUrl
#yt-dlp -o "$output_dir/%(title)s.%(ext)s" --extract-audio --audio-format wav $playlistUrl

# Video
yt-dlp -f "bv*+ba/b" -o "$output_dir/%(title)s.%(ext)s" "$playlistUrl"

# Convert downloaded WEBM videos to MP4 and clean up
Get-ChildItem "$output_dir\*.*" | ForEach-Object {
    if (Test-Path $_.FullName) {
        $filename = [System.IO.Path]::GetFileNameWithoutExtension($_.Name)
        $cleaned_filename = $filename -replace '[^a-zA-Z0-9.]', ''
        $output_file = "$output_dir\$cleaned_filename.mp4"

        ffmpeg.exe -i $_.FullName -c:v libx264 -c:a aac -movflags +faststart $output_file

        if ($LASTEXITCODE -eq 0) {
            Remove-Item $_.FullName -Force
        }
    }
}

Write-Host "Playlist downloaded, converted to MP3, and original files removed."
