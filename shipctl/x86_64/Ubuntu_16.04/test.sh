echo './shipctl get_git_changes --path="$HOME/s/node"'
./shipctl get_git_changes --path="$HOME/s/node"
echo $?

echo "---->>>>"

echo './shipctl get_git_changes --resource="mygitRepo"'
./shipctl get_git_changes --resource="mygitRepo"
echo $?

echo "---->>>>"

echo './shipctl get_git_changes --path="$HOME/s/node" --depth=1'
./shipctl get_git_changes --path="$HOME/s/node" --depth=1
echo $?

echo "---->>>>"

echo './shipctl get_git_changes --path="$HOME/s/node" --directories-only'
./shipctl get_git_changes --path="$HOME/s/node" --directories-only
echo $?

echo "---->>>>"

echo './shipctl get_git_changes --path="$HOME/s/node" --depth=1 --directories-only'
./shipctl get_git_changes --path="$HOME/s/node" --depth=1 --directories-only
echo $?

echo "---->>>>"

echo './shipctl get_git_changes --path="$HOME/s/node" --depth=2 --directories-only'
./shipctl get_git_changes --path="$HOME/s/node" --depth=2 --directories-only
echo $?

echo "---->>>>"

echo './shipctl get_git_changes --path="$HOME/s/node" --depth=3 --directories-only'
./shipctl get_git_changes --path="$HOME/s/node" --depth=3 --directories-only
echo $?

echo "---->>>>"

echo './shipctl get_git_changes --path="$HOME/s/node" --depth=1 --directories-only --commit-range="HEAD..HEAD~100"'
./shipctl get_git_changes --path="$HOME/s/node" --depth=1 --directories-only --commit-range="HEAD..HEAD~100"
echo $?
