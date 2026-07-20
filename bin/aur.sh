for i in "$(cat aur.list.tx)"; do
	yay -Ss $i
done

