./shipctl get_git_changes --path="$HOME/s/node"
echo $?

echo "---->>>>"

./shipctl get_git_changes --resource="mygitRepo"
echo $?

echo "---->>>>"

./shipctl get_git_changes --path="$HOME/s/node" --depth=1
echo $?

echo "---->>>>"

./shipctl get_git_changes --path="$HOME/s/node" --directories-only
echo $?

echo "---->>>>"

./shipctl get_git_changes --path="$HOME/s/node" --depth=1 --directories-only
echo $?

echo "---->>>>"

./shipctl get_git_changes --path="$HOME/s/node" --depth=2 --directories-only
echo $?

echo "---->>>>"

./shipctl get_git_changes --path="$HOME/s/node" --depth=3 --directories-only
echo $?

echo "---->>>>"

./shipctl get_git_changes --path="$HOME/s/node" --depth=1 --directories-only --commit-range="HEAD..HEAD~100"
echo $?
