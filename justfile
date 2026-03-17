android:
    flutter clean 
    flutter pub get 
    flutter build appbundle --release --tree-shake-icons --obfuscate --split-debug-info=build/native-debug-symbols

android-apk:
    flutter build apk --release --split-per-abi --tree-shake-icons --obfuscate --split-debug-info=build/native-debug-symbols

android-debug:
    flutter build apk --debug

android-analyze:
    flutter build apk --release --analyze-size
