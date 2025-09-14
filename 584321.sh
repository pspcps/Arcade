# Prompt for region input
read -p "Enter REGION: " REGION
echo

# Confirm user input
echo "You have entered the region: $REGION"
echo

# Fetch GCP Project ID
ID="$(gcloud projects list --format='value(PROJECT_ID)')"

# Generate Image Python Script
cat > GenerateImage.py <<EOF
import argparse
import vertexai
from vertexai.preview.vision_models import ImageGenerationModel

def generate_image(
    project_id: str, location: str, output_file: str, prompt: str
):
    vertexai.init(project=project_id, location=location)
    model = ImageGenerationModel.from_pretrained("imagen-3.0-generate-002")
    images = model.generate_images(
        prompt=prompt,
        number_of_images=1,
        seed=1,
        add_watermark=False,
    )
    images[0].save(location=output_file)
    return images

generate_image(
    project_id='$ID',
    location='$REGION',
    output_file='image.jpeg',
    prompt='Create an image containing a bouquet of 2 sunflowers and 3 roses',
)
EOF

echo "Generating an image of flowers... Please wait."
/usr/bin/python3 /home/student/GenerateImage.py
echo "Image generated successfully! Check 'image.jpeg' in your working directory."

# Multimodal Analysis Script
cat > genai.py <<EOF
import vertexai
from vertexai.generative_models import GenerativeModel, Part, Image, Content
import sys

def analyze_bouquet_image(project_id: str, location: str):
    vertexai.init(project=project_id, location=location)
    model = GenerativeModel("gemini-2.0-flash-001")

    image_path = "/home/student/image.jpeg"
    image_part = Part.from_image(Image.load_from_file(image_path))

    print("Image Analysis: ", end="", flush=True)
    response_stream = model.generate_content(
        [
            image_part,
            Part.from_text("What is shown in this image?")
        ],
        stream=True
    )

    full_response = ""
    for chunk in response_stream:
        if chunk.text:
            print(chunk.text, end="", flush=True)
            full_response += chunk.text
    print("\\n")

    chat_history = [
        Content(role="user", parts=[image_part, Part.from_text("What is shown in this image?")]),
        Content(role="model", parts=[Part.from_text(full_response)])
    ]

    chat = model.start_chat(history=chat_history)

    print("\\nChat with Gemini (type 'exit' to quit):")

    while True:
        user_input = input("You: ")
        if user_input.lower() == "exit":
            break

        try:
            response_stream = chat.send_message(user_input, stream=True)
            print("Gemini: ", end="", flush=True)
            for chunk in response_stream:
                if chunk.text:
                    print(chunk.text, end="", flush=True)
            print()

        except Exception as e:
            print(f"Error: {e}")
            break

project_id = "$ID"
location = "$REGION"

analyze_bouquet_image(project_id, location)
EOF

echo "Analyzing the generated image with Gemini..."
/usr/bin/python3 /home/student/genai.py
