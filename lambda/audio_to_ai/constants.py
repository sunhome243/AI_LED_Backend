"""
Configuration constants for the AI LED Backend orchestrator
"""

# Dynamic mode mapping to IR codes
DYNAMIC_MODES = {
    "FLASH": 0,
    "STROBE": 1,
    "FADE": 2,
    "SMOOTH": 3,
    "JUMP3": 4,
    "JUMP7": 5,
    "FADE3": 6,
    "FADE7": 7,
    "MUSIC1": 8,
    "MUSIC2": 9,
    "MUSIC3": 10,
    "MUSIC4": 11
}

# Valid dynamic modes for validation
VALID_DYNAMIC_MODES = [
    "FLASH", "STROBE", "FADE", "SMOOTH",
    "JUMP3", "JUMP7", "FADE3", "FADE7",
    "MUSIC1", "MUSIC2", "MUSIC3", "MUSIC4"
]

# IR code ID to key mapping
IR_CODE_MAP = {
    12: "r_up",
    13: "r_down",
    14: "g_up",
    15: "g_down",
    16: "b_up",
    17: "b_down",
    18: "power",
    19: "enterDiy"
}

# Default result template for IR codes
DEFAULT_IR_RESULT = {
    "power": None,
    "r_up": None,
    "r_down": None,
    "g_up": None,
    "g_down": None,
    "b_up": None,
    "b_down": None,
    "dynamic": None,
    "enterDiy": None
}
