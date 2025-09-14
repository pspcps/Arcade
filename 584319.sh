read -p "Enter REGION: " REGION_INPUT
export REGION=$REGION_INPUT

if [ -z "$REGION" ]; then
    echo "Error: REGION is not set. Please set the REGION before running the script."
    exit 1
fi

echo "Region set to: $REGION"

ID="$(gcloud projects list --format='value(PROJECT_ID)')"

echo "Project ID: $ID"

# Prompt for user to input a prompt
echo "Defining the prompt for the image generation..."

cat > GenerateImage.py <<EOF
import argparse
import vertexai
from vertexai.preview.vision_models import ImageGenerationModel

def generate_image(
    project_id: str, location: str, output_file: str, prompt: str
):
    """Generate an image using a text prompt.
    Args:
      project_id: Google Cloud project ID, used to initialize Vertex AI.
      location: Google Cloud region, used to initialize Vertex AI.
      output_file: Local path to the output image file.
      prompt: The text prompt describing what you want to see."""

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
    prompt='Create an image of a cricket ground in the heart of Los Angeles',
)
EOF


echo "Running the image generation process..."
/usr/bin/python3 /home/student/GenerateImage.py

echo
