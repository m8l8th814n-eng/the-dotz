#!/bin/sh
# usage: start-mango.sh [hdr|effects]
#   hdr     (default) vulkan renderer: HDR, no scenefx effects
#   effects gles renderer: rounded corners/shadows/blur, no HDR
case "${1:-hdr}" in
effects|gles)
	exec mango -d 2>/home/simon/mango-effects.log
	;;
esac
env WLR_RENDERER=vulkan ENABLE_HDR_WSI=1 mango -d 2>/home/simon/mango-hdr.log
[ $? -ne 0 ] && exec mango -d 2>/home/simon/mango-gles-fallback.log
