@echo off
del build /q /s /f
rd build /q /s
mkdir build
dart compile exe bin/main.dart -o ./build/bili_novel_packer-a0.1.2-M4.exe