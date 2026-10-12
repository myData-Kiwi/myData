`qwen3:14b`. Cold = model just loaded and prompt not cached; warm = loaded, prefix cached. Generation speed from a 128-token answer.

| When | Load s | Cold prompt read tok/s | Warm prompt read s | Generation tok/s (warm) | Memory free | Swap used | Pages out / swapped out during the phase | Battery / system °C | Load avg | Power |
|---|---|---|---|---|---|---|---|---|---|---|
| start | 8.84 | 100.9 (1816 tokens in 18.01 s) | 20.35 | 10.9 | 81% | 13.9 GB | 0 / 0 | - / - | { 3.28 3.44 3.58 } | battery 66% |
| after 10 minutes | 1.05 | 63.2 (1817 tokens in 28.76 s) | 27.24 | 8.4 | 29% | 13.6 GB | 0 / 0 | - / - | { 3.13 3.52 3.62 } | battery 62% |

During 10 minutes of continuous requests (76 model calls): generation 10.7 tok/s (first fifth) → 8.7 tok/s (last fifth); all calls 6.3–11.5.

| Minute | Memory free | Pages out / swapped out since the last minute | Battery / system °C | Busiest processes |
|---|---|---|---|---|
| 0 | 37% | - | - / - | 99.1 /usr/sbin/BTLEServer; 19.7 /System/Library/PrivateFrameworks/SkyLight.framework/Resources/WindowServer; 14.9 /System/Library/PrivateFrameworks/IDS.framework/identityservicesd.app/Contents/MacOS/identityservicesd |
| 1 | 37% | - | - / - | 99.6 /usr/sbin/BTLEServer; 9.2 /Applications/Ollama.app/Contents/Resources/llama-server; 8.3 /Users/patelti4/.vscode/extensions/anthropic.claude-code-2.1.296-darwin-arm64/resources/native-binary/claude |
| 2 | 37% | - | - / - | 100.0 /usr/sbin/BTLEServer; 20.1 /sbin/launchd; 12.5 /System/Library/PrivateFrameworks/SkyLight.framework/Resources/WindowServer |
| 3 | 35% | - | - / - | 133.6 /usr/sbin/coreaudiod; 96.6 /usr/sbin/BTLEServer; 27.1 /System/Library/PrivateFrameworks/SkyLight.framework/Resources/WindowServer |
| 4 | 37% | - | - / - | 99.2 /usr/sbin/BTLEServer; 6.2 /System/Library/PrivateFrameworks/SkyLight.framework/Resources/WindowServer; 6.1 /Applications/Ollama.app/Contents/Resources/llama-server |
| 5 | 35% | - | - / - | 100.0 /usr/sbin/BTLEServer; 50.5 /System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/Metadata.framework/Versions/A/Support/corespotlightd; 16.8 /System/Library/PrivateFrameworks/SkyLight.framework/Resources/WindowServer |
| 6 | 32% | - | - / - | 98.2 /usr/sbin/BTLEServer; 23.8 /System/Library/PrivateFrameworks/SkyLight.framework/Resources/WindowServer; 6.1 /Applications/Ollama.app/Contents/Resources/llama-server |
| 7 | 32% | - | - / - | 100.0 /usr/sbin/BTLEServer; 10.8 /Applications/ESET Endpoint Security.app/Contents/MacOS/sysinfod; 9.5 /Applications/Ollama.app/Contents/Resources/llama-server |
| 8 | 31% | - | - / - | 99.2 /usr/sbin/BTLEServer; 36.7 /usr/sbin/coreaudiod; 28.5 /System/Library/PrivateFrameworks/SkyLight.framework/Resources/WindowServer |
| 9 | 29% | - | - / - | 98.4 /usr/sbin/BTLEServer; 30.9 /System/Library/PrivateFrameworks/SkyLight.framework/Resources/WindowServer; 9.3 /Applications/ESET Endpoint Security.app/Contents/MacOS/sysinfod |
| 10 | 29% | - | - / - | 98.7 /usr/sbin/BTLEServer; 16.9 /System/Library/PrivateFrameworks/SkyLight.framework/Resources/WindowServer; 14.3 /usr/sbin/coreaudiod |
