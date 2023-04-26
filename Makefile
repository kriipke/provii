SHELL=/bin/bash

manifest:
	@echo "Generating installer manifest..."
	@ls repository | jq -R -s -c 'split("\n")' | jq '[ .[] | select(length > 0) ]' > repository/manifest.json

clean:
	@echo "Cleaning up..."
	rm share/*.png
