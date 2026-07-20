docker run -d \
--device /dev/kfd \
--device /dev/dri/renderD128 \
-v ollama:/root/.ollama \
-p 11434:11434 \
-e HSA_OVERRIDE_GFX_VERSION=10.3.0 \
--name ollama \
ollama/ollama:rocm
