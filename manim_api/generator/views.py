import os
import shutil
import subprocess
import tempfile
import json
from datetime import datetime
from django.conf import settings
from rest_framework.decorators import api_view
from rest_framework.response import Response


@api_view(['POST'])
def generate_animation(request):
    prompt = request.data.get('prompt', '')
    if not prompt:
        return Response({'error': 'No prompt provided'}, status=400)

    os.makedirs(settings.MEDIA_ROOT, exist_ok=True)

    timestamp = datetime.now().strftime('%Y%m%d_%H%M%S_%f')
    base_name = f"scene_{timestamp}"

    safe_prompt_literal = json.dumps(prompt)

    script = f'''
from manim import *

class GeneratedScene(Scene):
    def construct(self):
        text = Text({safe_prompt_literal}, font_size=48)
        self.play(Write(text))
        self.wait(2)
'''

    with tempfile.NamedTemporaryFile(mode='w', suffix='.py', delete=False, encoding='utf-8') as temp_script_file:
        temp_script_file.write(script)
        py_path = temp_script_file.name

    # ملف الفيديو النهائي مباشرة داخل media/
    final_video_name = f"{base_name}.mp4"
    final_video_path = os.path.join(settings.MEDIA_ROOT, final_video_name)

    # أمر Manim
    command = [
        "manim", py_path, "GeneratedScene",
        "-ql",
        "--disable_caching",
        "--media_dir", settings.MEDIA_ROOT,
        "--output_file", final_video_path
    ]

    try:
        subprocess.run(
            command, check=True, capture_output=True, text=True, encoding='utf-8'
        )

        video_url = settings.MEDIA_URL + final_video_name

        return Response({
            "status": "success",
            "video_url": video_url
        })

    except subprocess.CalledProcessError as exc:
        return Response({
            "status": "error",
            "error": "Manim failed to generate the video.",
            "stdout": exc.stdout,
            "stderr": exc.stderr
        }, status=500)

    finally:
        if os.path.exists(py_path):
            os.remove(py_path)