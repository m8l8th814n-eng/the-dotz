for i in 3 2 1 0; do
echo $i | sudo tee /sys/class/leds/asus::kbd_backlight/brightness
done
