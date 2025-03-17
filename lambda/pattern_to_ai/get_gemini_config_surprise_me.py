from google import genai


def get_gemini_config():
    """
    Returns the configuration for the Gemini AI model.

    Returns:
        GenerateContentConfig: The configuration for the Gemini AI model.
    """
    return genai.types.GenerateContentConfig(
        temperature=0.85,
        top_p=0.95,
        top_k=40,
        max_output_tokens=8192,
        response_mime_type="application/json",
        response_schema=genai.types.Schema(
            type=genai.types.Type.OBJECT,
            enum=[],
            required=["lightSetting", "emotion", "recommendation", "context"],
            properties={
                "lightSetting": genai.types.Schema(
                    type=genai.types.Type.OBJECT,
                    enum=[],
                    required=["power"],
                    properties={
                        "color": genai.types.Schema(
                            type=genai.types.Type.ARRAY,
                            items=genai.types.Schema(
                                type=genai.types.Type.STRING,
                            ),
                        ),
                        "power": genai.types.Schema(
                            type=genai.types.Type.BOOLEAN,
                        ),
                        "dynamic": genai.types.Schema(
                            type=genai.types.Type.STRING,
                        ),
                    },
                ),
                "emotion": genai.types.Schema(
                    type=genai.types.Type.OBJECT,
                    description="Emotion analysis result",
                    enum=[],
                    required=["main", "subcategories"],
                    properties={
                        "main": genai.types.Schema(
                            type=genai.types.Type.STRING,
                        ),
                        "subcategories": genai.types.Schema(
                            type=genai.types.Type.ARRAY,
                            items=genai.types.Schema(
                                type=genai.types.Type.STRING,
                            ),
                        ),
                    },
                ),
                "recommendation": genai.types.Schema(
                    type=genai.types.Type.STRING,
                ),
                "context": genai.types.Schema(
                    type=genai.types.Type.STRING,
                ),
            },
        ),
        system_instruction=[
            genai.types.Part.from_text(
                text="""Adaptive Personalized Lighting Assistant

You are an AI that predicts and personalizes lighting based on broad time patterns, emotional state, and user context. Instead of matching exact timestamps, you analyze general trends to infer the most likely current activity. The AI must select either RGB color or Dynamic mode—never both.

Core Functions
	•	Pattern Recognition: Retrieve and analyze past records (weekday, time range, emotion, context, RGB code, user feedback) to identify trends, not exact timestamps.
	•	Context-Aware Prediction: If multiple past activities exist within a time range, choose the most frequent or contextually relevant one, rather than the latest.
	•	Lighting Optimization: Adjust brightness and color dynamically based on historical patterns and current context.
	•	Strict Output Rule: Only one lighting mode is allowed—either RGB color or Dynamic mode, never both.

Output Schema

1️⃣ User Activity (activity)
	•	main: General category (e.g., \"study\", \"reading\", \"movie\").
	•	sub: Specific details (\"math\", \"comic book\", \"horror movie\").

2️⃣ Light Settings (lightSetting)
	•	Choose ONE of the following:
	•	RGB Color: [R, G, B] based on prior preferences and environmental factors.
	•	Dynamic Mode: \"FADE3\", \"MUSIC2\", etc. (Only if the activity requires it, e.g., music, party, gaming.)
	•	Brightness Scaling: Adjust brightness based on time, activity, and previous feedback.
	•	Power: true (on) or false (off).

3️⃣ Emotional Analysis (emotion)
	•	main: \"Positive\", \"Negative\", \"Neutral\"
	•	sub: Top 3 detected emotions.

4️⃣ Recommendation (recommendation)
	•	Explain why this lighting choice was made.
	•	Example: \"Since you usually study between 12 PM - 3 PM on Mondays, bright white light is set for focus. Stay productive! ✨\"

5️⃣ Context (context)
	•	Concise description (e.g., \"Monday afternoon study session, feeling focused.\").

Guidelines

Generalized Time Analysis
	•	Instead of exact timestamps, analyze a time block (e.g., 14:00 - 15:00).
	•	If multiple activities exist, prioritize the most frequent or logical choice.
	•	If no clear pattern emerges, default to the most contextually fitting option.

Strict Lighting Mode Selection
	•	RGB Color Mode → For studying, reading, movies, relaxing.
	•	Dynamic Mode → For music, parties, gaming (only if needed).
	•	Never use both RGB and Dynamic Mode together.

Conflict Resolution
	•	If some pattern occurs often, but some patterns are rare, choose the dominant pattern (study/reading) even if the latest entry was a horror movie.

Fallback Defaults
	•	If no strong pattern is detected, infer activity using general time-of-day behavior.

Example Correct Output (Fixing the Issue)

Past Data Analysis (14:00 - 15:00 on Mondays)
	•	Study @ 14:00 (Bright White)
	•	Reading a book @ 14:20 (Bright White)
	•	Reading a comic book @ 14:20 (Slightly Warm White)
	•	Watching a horror movie @ 14:43 (Dim Red)

Current Time: Monday, 14:30

✅ Study and reading are more frequent than horror movies.
✅ The AI selects only RGB mode (no Dynamic Mode).

{
  \"context\": \"It's Monday afternoon, and you're likely studying or reading.\",
  \"emotion\": {
    \"main\": \"Neutral\",
    \"subcategories\": [
      \"Focused\",
      \"Calm\",
      \"Engaged\"
    ]
  },
  \"lightSetting\": {
    \"power\": true,
    \"color\": [
      \"255\",
      \"255\",
      \"250\"
    ]
  },
  \"recommendation\": \"Since you often study or read around this time on Mondays, a bright white light is set to help you focus. Keep up the good work! 📚✨\"
}
"""
            ),
        ],
    )
