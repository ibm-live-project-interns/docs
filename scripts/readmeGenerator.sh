#!/bin/bash
# this script will generate multiple readme.md file under below path
base_dir="../docs/arch"

# Map of folder names to custom text
get_custom_text() {
  case "$1" in
    AIProcessing) echo "Core AI intelligent processing components including Agents-api REST interface, LLM Service integration for natural language log explanation and severity classification, RAG Connector for knowledge base retrieval, and Rule-Based Engine for alert validation and remediation suggestions.";;
    DataSource) echo "Data source adapters and simulators responsible for capturing SNMP traps, syslogs, and device metadata. Includes parsers for raw network device outputs and tools for emulating device behavior during testing.";;
    Ingestor) echo "Collector and ingestion services that receive and normalize raw logs from the DataSource layer. Handles timestamp normalization, OID to friendly name mapping, device metadata enrichment, and batching of logs for efficient downstream processing.";;
    Output\&Integration) echo "Services handling storage of processed alerts and integration with user-facing components. Hosts the Agents-api endpoints for the UI to fetch alerts, manages the Alerts DB, and supports integration connectors such as automatic incident creation in ticketing systems like ServiceNow.";;
    UI) echo "User Interface components including dashboard views presenting alert summary, severity visualization, explanation panels, recommended actions, and filters. Provides real-time updates, historical alert navigation, and quick-action controls for network operators.";;
    *) echo "Custom text for the folder: $1";;
  esac
}


# Python helper function for PlantUML encoding
plantuml_encode() {
  python3 -c '
import sys, zlib

def encode_plantuml(text):
    def deflate(data):
        compressor = zlib.compressobj(level=9, wbits=-15)
        compressed = compressor.compress(data) + compressor.flush()
        return compressed

    def encode6bit(b):
        if b < 10:
            return chr(48 + b)
        b -= 10
        if b < 26:
            return chr(65 + b)
        b -= 26
        if b < 26:
            return chr(97 + b)
        b -= 26
        if b == 0:
            return "-"
        if b == 1:
            return "_"
        return "?"

    def append3bytes(b1, b2, b3):
        c1 = b1 >> 2
        c2 = ((b1 & 0x3) << 4) | (b2 >> 4)
        c3 = ((b2 & 0xF) << 2) | (b3 >> 6)
        c4 = b3 & 0x3F
        r = ""
        r += encode6bit(c1 & 0x3F)
        r += encode6bit(c2 & 0x3F)
        r += encode6bit(c3 & 0x3F)
        r += encode6bit(c4 & 0x3F)
        return r

    data = text.encode("utf-8")
    compressed = deflate(data)
    res = ""
    i = 0
    while i < len(compressed):
        b1 = compressed[i]
        b2 = compressed[i+1] if i+1 < len(compressed) else 0
        b3 = compressed[i+2] if i+2 < len(compressed) else 0
        res += append3bytes(b1, b2, b3)
        i += 3
    return res

text = sys.stdin.read()
print(encode_plantuml(text), end="")
' 
}

for dir in "$base_dir"/*; do
  if [ -d "$dir" ]; then
    folder_name=$(basename "$dir")
    img_dir="$dir/images"
    mkdir -p "$img_dir"

    readme_file="$dir/README.md"
    > "$readme_file"

    # Add custom text if present in map
    echo "$(get_custom_text "$folder_name")" >> "$readme_file"

    echo "" >> "$readme_file"
    echo "### UML Diagrams in this folder:" >> "$readme_file"
    echo "" >> "$readme_file"

    for uml in "$dir"/*.puml; do
      if [ -f "$uml" ]; then
        filename=$(basename "$uml")
        png_name="${filename%.puml}.png"
        encoded=$(plantuml_encode < "$uml")
        img_url="http://www.plantuml.com/plantuml/png/$encoded"

        if [ ! -f "$img_dir/$png_name" ]; then
          curl -s -o "$img_dir/$png_name" "$img_url"
        fi

        echo "#### $filename" >> "$readme_file"
        echo "" >> "$readme_file"
        echo "![${png_name}](images/$png_name)" >> "$readme_file"
        echo "" >> "$readme_file"
      fi
    done
  fi
done

echo "README.md files updated with local PlantUML images and custom text."
