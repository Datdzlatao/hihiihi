import subprocess

sh_code = """
for t in /proc/19167/task/*; do
    tid=$(basename $t)
    comm=$(cat $t/comm 2>/dev/null)
    wchan=$(cat $t/wchan 2>/dev/null)
    echo "$tid ($comm) wchan=$wchan"
done
"""

p = subprocess.run(['adb', '-s', '282f344c', 'shell', f"run-as org.capyps5.emulator.debug sh -c '{sh_code}'"], capture_output=True, text=True)
print(p.stdout)
print(p.stderr)
