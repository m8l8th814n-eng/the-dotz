tr '\0' '\n' < /proc/$(pgrep -x mango)/environ | grep WLR   # ska visa WLR_RENDERER=vulkan
