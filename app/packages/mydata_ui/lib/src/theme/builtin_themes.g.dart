// GENERATED from design/themes (theme.schema.json and every <slug>/theme.json) and design/tokens.json
// by tool/generate_tokens.dart. Do not edit: change the JSON and run
//   (cd app/packages/mydata_ui && dart run tool/generate_tokens.dart)
// ignore_for_file: public_member_api_docs

/// theme.schema.json, the format every theme file is checked against.
const themeSchemaJson = r'''{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "urn:mydata:theme:1",
  "title": "myData theme, format 1",
  "description": "theme.json inside a .mydatatheme file, and every built-in theme in design/themes/<slug>/theme.json. Data only: no URLs, paths (except the two image slots), CSS, expressions or code. Every number has bounds. A theme is a style (type, shape, density, borders, elevation, materials, icons, motion, components) plus one or more palettes; colours live only in palettes. The schema is the first gate; contrast and the other rules in ARCHITECTURE.md section 2 are the second, run by the same validator in the apps, the editor and the tests. Keys use kebab-case like design/tokens.json.",
  "type": "object",
  "additionalProperties": true,
  "$comment": "Unknown keys are allowed by the schema so a newer minor version still loads; the validator drops them and reports a notice. A newer major 'format' is refused before this schema runs.",
  "required": [
    "format",
    "id",
    "name",
    "version",
    "licence",
    "frame"
  ],
  "properties": {
    "$schema": {
      "type": "string",
      "maxLength": 200,
      "$comment": "Informational only. Never fetched."
    },
    "format": {
      "const": 1
    },
    "id": {
      "type": "string",
      "description": "Built-in: 'mydata.<slug>'. Everything else: a lower-case UUID. An imported file may not use the 'mydata.' prefix.",
      "oneOf": [
        {
          "pattern": "^mydata\\.[a-z][a-z0-9-]{1,31}$"
        },
        {
          "pattern": "^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$"
        }
      ]
    },
    "name": {
      "$ref": "#/$defs/shortText",
      "maxLength": 40
    },
    "version": {
      "type": "string",
      "pattern": "^(0|[1-9][0-9]{0,3})\\.(0|[1-9][0-9]{0,3})\\.(0|[1-9][0-9]{0,3})$"
    },
    "author": {
      "$ref": "#/$defs/shortText",
      "maxLength": 80
    },
    "licence": {
      "type": "string",
      "maxLength": 64,
      "pattern": "^([A-Za-z0-9.+-]+|NOASSERTION)$",
      "description": "One SPDX licence identifier (checked against the SPDX list compiled into the app), or NOASSERTION for a theme that is not shared. Export asks for one if NOASSERTION."
    },
    "description": {
      "$ref": "#/$defs/shortText",
      "maxLength": 280
    },
    "based-on": {
      "type": "string",
      "pattern": "^mydata\\.[a-z][a-z0-9-]{1,31}$",
      "description": "A built-in id only. Fills every style group this file leaves out; never palettes, which a drawn file always gives. Never a fetch, never another custom theme."
    },
    "frame": {
      "enum": [
        "system",
        "drawn"
      ],
      "description": "system: the platform's own look (the Mac shell on macOS); only the built-in System and 'System, tinted' copies may use it, and their palettes may set an accent only (the built-in System has none: its colour is the platform's accent). A 'System, tinted' palette is never applied on macOS, where the accent is always the system's (ARCHITECTURE.md 1.6). drawn: myData draws everything inside the window with this file's rules."
    },
    "preview": {
      "type": "object",
      "additionalProperties": false,
      "description": "How the gallery introduces the theme. Pictures are always rendered live; a file never carries a screenshot.",
      "properties": {
        "blurb": {
          "$ref": "#/$defs/shortText",
          "maxLength": 80
        },
        "scene": {
          "enum": [
            "contacts",
            "calendar",
            "assistant",
            "status"
          ]
        }
      }
    },
    "palettes": {
      "type": "array",
      "minItems": 1,
      "maxItems": 8,
      "description": "The colour choices of this theme, named by colour (Journal: Plum, Ink blue, Forest). The user picks a theme and one of its palettes, per app and per device. Each palette is resolved and checked on its own, in both modes and at increased contrast (ARCHITECTURE.md 1.6 and 2). Ids are unique within the theme (checked by the validator)."
    },
    "default-palette": {
      "type": "string",
      "pattern": "^[a-z][a-z0-9-]{1,31}$",
      "description": "The id of the palette used when none is chosen, or when the chosen one no longer exists. Must name one of palettes (checked by the validator). Only with palettes."
    },
    "colour-use": {
      "$ref": "#/$defs/colourUse"
    },
    "type": {
      "$ref": "#/$defs/type"
    },
    "shape": {
      "$ref": "#/$defs/shape"
    },
    "density": {
      "$ref": "#/$defs/density"
    },
    "borders": {
      "$ref": "#/$defs/borders"
    },
    "elevation": {
      "$ref": "#/$defs/elevation"
    },
    "materials": {
      "$ref": "#/$defs/materials"
    },
    "icons": {
      "$ref": "#/$defs/icons"
    },
    "motion": {
      "$ref": "#/$defs/motion"
    },
    "components": {
      "$ref": "#/$defs/components"
    },
    "illustration": {
      "enum": [
        "flat",
        "line",
        "pixel",
        "ink"
      ],
      "description": "The kiwi's drawing style on empty and loading screens. Falls back to flat while a style is not drawn."
    },
    "accessibility": {
      "type": "object",
      "additionalProperties": false,
      "description": "What this style promises beyond the rules every theme keeps (High Contrast, E-ink, Large). A file that leaves it out promises nothing more; one based on another theme keeps that theme's promises unless it says otherwise.",
      "properties": {
        "text-contrast": {
          "enum": [
            "4.5:1",
            "7:1"
          ],
          "description": "The least contrast every text pair of every palette is checked at, at normal contrast too (7:1: accessibility-first, WCAG 1.4.6). Increased contrast always asks 7:1. Default 4.5:1."
        },
        "faint-text": {
          "enum": [
            "system",
            "readable"
          ],
          "description": "Faint text in the Mac window (a disabled item, another month's day): the system's faint shade over ink, or readable, a grey at 4.5:1, as at increased contrast. Default system."
        }
      }
    },
    "sound": {
      "const": "none",
      "description": "Reserved. Themes make no sound."
    }
  },
  "allOf": [
    {
      "if": {
        "properties": {
          "frame": {
            "const": "drawn"
          }
        }
      },
      "then": {
        "required": [
          "palettes",
          "default-palette"
        ],
        "properties": {
          "palettes": {
            "items": {
              "$ref": "#/$defs/palette"
            }
          }
        }
      }
    },
    {
      "if": {
        "properties": {
          "frame": {
            "const": "system"
          }
        }
      },
      "then": {
        "properties": {
          "palettes": {
            "items": {
              "$ref": "#/$defs/systemPalette"
            }
          }
        },
        "not": {
          "anyOf": [
            {
              "required": [
                "type"
              ]
            },
            {
              "required": [
                "shape"
              ]
            },
            {
              "required": [
                "density"
              ]
            },
            {
              "required": [
                "borders"
              ]
            },
            {
              "required": [
                "elevation"
              ]
            },
            {
              "required": [
                "materials"
              ]
            },
            {
              "required": [
                "icons"
              ]
            },
            {
              "required": [
                "motion"
              ]
            },
            {
              "required": [
                "components"
              ]
            },
            {
              "required": [
                "colour-use"
              ]
            }
          ]
        },
        "dependentRequired": {
          "palettes": [
            "default-palette"
          ]
        }
      }
    },
    {
      "$comment": "Built-in drawn themes have 2 to 4 palettes (ARCHITECTURE.md 1.6).",
      "if": {
        "required": [
          "id",
          "frame"
        ],
        "properties": {
          "id": {
            "pattern": "^mydata\\."
          },
          "frame": {
            "const": "drawn"
          }
        }
      },
      "then": {
        "properties": {
          "palettes": {
            "minItems": 2,
            "maxItems": 4
          }
        }
      }
    }
  ],
  "dependentRequired": {
    "default-palette": [
      "palettes"
    ]
  },
  "$defs": {
    "shortText": {
      "type": "string",
      "minLength": 1,
      "$comment": "Plain text, shown as text (never Markdown, never a link). The validator strips control (Cc) and format (Cf) characters, bidi overrides included, and normalises to NFC before the length check."
    },
    "opaque": {
      "type": "string",
      "pattern": "^#[0-9A-Fa-f]{6}$"
    },
    "translucent": {
      "type": "string",
      "pattern": "^#[0-9A-Fa-f]{6}([0-9A-Fa-f]{2})?$"
    },
    "paletteId": {
      "type": "string",
      "pattern": "^[a-z][a-z0-9-]{1,31}$"
    },
    "palette": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "name",
        "light",
        "dark"
      ],
      "description": "One palette of a drawn theme: the six seeds per mode, and optionally any other role, an increased-contrast set and the window gradient's stops. Roles left out are derived from the seeds (ARCHITECTURE.md 1.3); roles the theme fixes in colour-use.same-as may not be given (checked by the validator). Built-in palettes give every role the theme does not fix in colour-use.same-as (all 43 once resolved), so they never depend on the resolver's derivation.",
      "properties": {
        "id": {
          "$ref": "#/$defs/paletteId"
        },
        "name": {
          "$ref": "#/$defs/shortText",
          "maxLength": 24,
          "description": "A colour name, in sentence case: \"Ink blue\", not \"Journal ink blue\"."
        },
        "light": {
          "$ref": "#/$defs/colourSeeds"
        },
        "dark": {
          "$ref": "#/$defs/colourSeeds"
        },
        "overrides": {
          "type": "object",
          "additionalProperties": false,
          "properties": {
            "light": {
              "$ref": "#/$defs/colourOverrides"
            },
            "dark": {
              "$ref": "#/$defs/colourOverrides"
            }
          }
        },
        "contrast": {
          "type": "object",
          "additionalProperties": false,
          "description": "Optional values used when the system asks for more contrast (macOS Increase contrast). Without them the resolver derives them (ARCHITECTURE.md 2.2, 7:1 row). Checked at 7:1 for text.",
          "properties": {
            "light": {
              "$ref": "#/$defs/colourSetPartial"
            },
            "dark": {
              "$ref": "#/$defs/colourSetPartial"
            }
          }
        },
        "gradient": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "light",
            "dark"
          ],
          "description": "The window gradient's stops, used when the theme's materials.window.kind is gradient. Left out, they are derived: bg mixed 8% towards accent, bg, and bg mixed 5% towards ink. Given on a theme whose window is not a gradient, they are ignored with a notice (checked by the validator).",
          "properties": {
            "light": {
              "type": "array",
              "minItems": 2,
              "maxItems": 3,
              "items": {
                "$ref": "#/$defs/opaque"
              }
            },
            "dark": {
              "type": "array",
              "minItems": 2,
              "maxItems": 3,
              "items": {
                "$ref": "#/$defs/opaque"
              }
            }
          }
        }
      }
    },
    "systemPalette": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "name",
        "light",
        "dark"
      ],
      "description": "A palette of a system-frame theme (\"System, tinted\", phase 5; never on macOS, decided 2026-10-23): an accent in both modes and nothing else. Never applied on macOS, where the accent is always the system's. Checked as a palette on the grounds System draws on that platform, text at 4.5:1 (ARCHITECTURE.md 1.6). The built-in System has no palettes: its colour is the platform's accent.",
      "properties": {
        "id": {
          "$ref": "#/$defs/paletteId"
        },
        "name": {
          "$ref": "#/$defs/shortText",
          "maxLength": 24
        },
        "light": {
          "type": "object",
          "additionalProperties": false,
          "properties": {
            "accent": {
              "$ref": "#/$defs/opaque"
            }
          },
          "required": [
            "accent"
          ]
        },
        "dark": {
          "type": "object",
          "additionalProperties": false,
          "properties": {
            "accent": {
              "$ref": "#/$defs/opaque"
            }
          },
          "required": [
            "accent"
          ]
        }
      }
    },
    "colourSeeds": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "bg",
        "surface",
        "ink",
        "ink-muted",
        "accent",
        "on-accent"
      ],
      "description": "The six seed roles of one mode. Every other role is given in overrides or derived from these.",
      "properties": {
        "bg": {
          "$ref": "#/$defs/opaque"
        },
        "surface": {
          "$ref": "#/$defs/opaque"
        },
        "ink": {
          "$ref": "#/$defs/opaque"
        },
        "ink-muted": {
          "$ref": "#/$defs/opaque"
        },
        "accent": {
          "$ref": "#/$defs/opaque"
        },
        "on-accent": {
          "$ref": "#/$defs/opaque"
        }
      }
    },
    "colourOverrides": {
      "description": "Any role except the six seeds. brand, skin, cream and paper are fixed artwork colours and not part of a palette.",
      "allOf": [
        {
          "$ref": "#/$defs/colourSetPartial"
        },
        {
          "propertyNames": {
            "not": {
              "enum": [
                "bg",
                "surface",
                "ink",
                "ink-muted",
                "accent",
                "on-accent"
              ]
            }
          }
        }
      ]
    },
    "colourUse": {
      "type": "object",
      "additionalProperties": false,
      "description": "How the style uses colour, whatever the palette.",
      "properties": {
        "same-as": {
          "type": "object",
          "description": "Roles this style always draws in another role's colour, in every palette: Hairline's selection bar is ink, Journal's toolbar is the paper (bg). Applied after a palette's values, again after derivation, and again after the increased-contrast set or derivation (ARCHITECTURE.md 1.3). A key may not be a seed or a role a palette gives (in overrides or in a contrast set), and a value may not itself be a key (no chains); both are checked by the validator.",
          "propertyNames": {
            "enum": [
              "surface-raised",
              "surface-sunken",
              "surface-hover",
              "sidebar",
              "toolbar",
              "line",
              "line-strong",
              "edge",
              "accent-soft",
              "link",
              "selection",
              "on-selection",
              "selection-inactive",
              "focus",
              "focus-on-danger",
              "success",
              "success-soft",
              "warning",
              "warning-soft",
              "danger",
              "danger-soft",
              "on-danger",
              "info",
              "info-soft",
              "avatar-fill",
              "data-red",
              "data-orange",
              "data-yellow",
              "data-green",
              "data-blue",
              "data-purple",
              "data-brown",
              "data-grey",
              "scrim",
              "glass-fill",
              "glass-stroke",
              "shadow"
            ]
          },
          "additionalProperties": {
            "enum": [
              "bg",
              "surface",
              "surface-raised",
              "surface-sunken",
              "surface-hover",
              "sidebar",
              "toolbar",
              "line",
              "line-strong",
              "edge",
              "ink",
              "ink-muted",
              "accent",
              "on-accent",
              "accent-soft",
              "link",
              "selection",
              "on-selection",
              "selection-inactive",
              "focus",
              "focus-on-danger",
              "success",
              "success-soft",
              "warning",
              "warning-soft",
              "danger",
              "danger-soft",
              "on-danger",
              "info",
              "info-soft",
              "avatar-fill",
              "data-red",
              "data-orange",
              "data-yellow",
              "data-green",
              "data-blue",
              "data-purple",
              "data-brown",
              "data-grey",
              "scrim",
              "glass-fill",
              "glass-stroke",
              "shadow"
            ]
          }
        }
      }
    },
    "colourSetPartial": {
      "type": "object",
      "additionalProperties": false,
      "properties": {
        "bg": {
          "$ref": "#/$defs/opaque",
          "description": "Window ground."
        },
        "surface": {
          "$ref": "#/$defs/opaque"
        },
        "surface-raised": {
          "$ref": "#/$defs/opaque"
        },
        "surface-sunken": {
          "$ref": "#/$defs/opaque"
        },
        "surface-hover": {
          "$ref": "#/$defs/opaque"
        },
        "sidebar": {
          "$ref": "#/$defs/opaque",
          "description": "Sidebar ground when solid (and the fallback for a translucent one)."
        },
        "toolbar": {
          "$ref": "#/$defs/opaque",
          "description": "Toolbar ground when solid."
        },
        "line": {
          "$ref": "#/$defs/opaque",
          "description": "Decorative dividers."
        },
        "line-strong": {
          "$ref": "#/$defs/opaque",
          "description": "Edges that identify a control (3:1)."
        },
        "edge": {
          "$ref": "#/$defs/opaque",
          "description": "The theme's outline colour when borders.colour is 'edge' (ink outlines in Sticker, Brutalist)."
        },
        "ink": {
          "$ref": "#/$defs/opaque"
        },
        "ink-muted": {
          "$ref": "#/$defs/opaque"
        },
        "accent": {
          "$ref": "#/$defs/opaque",
          "description": "Fill of primary controls and on-state."
        },
        "on-accent": {
          "$ref": "#/$defs/opaque"
        },
        "accent-soft": {
          "$ref": "#/$defs/opaque"
        },
        "link": {
          "$ref": "#/$defs/opaque",
          "description": "Accent used as text (links, text buttons). Derived from accent; set it when accent cannot be text (a yellow accent)."
        },
        "selection": {
          "$ref": "#/$defs/opaque"
        },
        "on-selection": {
          "$ref": "#/$defs/opaque"
        },
        "selection-inactive": {
          "$ref": "#/$defs/opaque"
        },
        "focus": {
          "$ref": "#/$defs/opaque"
        },
        "focus-on-danger": {
          "$ref": "#/$defs/opaque"
        },
        "success": {
          "$ref": "#/$defs/opaque"
        },
        "success-soft": {
          "$ref": "#/$defs/opaque"
        },
        "warning": {
          "$ref": "#/$defs/opaque"
        },
        "warning-soft": {
          "$ref": "#/$defs/opaque"
        },
        "danger": {
          "$ref": "#/$defs/opaque"
        },
        "danger-soft": {
          "$ref": "#/$defs/opaque"
        },
        "on-danger": {
          "$ref": "#/$defs/opaque"
        },
        "info": {
          "$ref": "#/$defs/opaque"
        },
        "info-soft": {
          "$ref": "#/$defs/opaque"
        },
        "avatar-fill": {
          "$ref": "#/$defs/opaque",
          "description": "Was kiwi-wash."
        },
        "data-red": {
          "$ref": "#/$defs/opaque"
        },
        "data-orange": {
          "$ref": "#/$defs/opaque"
        },
        "data-yellow": {
          "$ref": "#/$defs/opaque"
        },
        "data-green": {
          "$ref": "#/$defs/opaque"
        },
        "data-blue": {
          "$ref": "#/$defs/opaque"
        },
        "data-purple": {
          "$ref": "#/$defs/opaque"
        },
        "data-brown": {
          "$ref": "#/$defs/opaque"
        },
        "data-grey": {
          "$ref": "#/$defs/opaque"
        },
        "scrim": {
          "$ref": "#/$defs/translucent"
        },
        "glass-fill": {
          "$ref": "#/$defs/translucent"
        },
        "glass-stroke": {
          "$ref": "#/$defs/translucent"
        },
        "shadow": {
          "$ref": "#/$defs/opaque",
          "description": "Shadow colour; strength comes from elevation."
        }
      },
      "description": "Any subset of the 43 colour roles of one mode (ARCHITECTURE.md 1.3)."
    },
    "fontStack": {
      "type": "array",
      "minItems": 1,
      "maxItems": 4,
      "description": "Catalogue font ids in order of preference, ending with a generic. Unknown ids are skipped with a notice, so a newer catalogue never breaks an older app.",
      "items": {
        "type": "string",
        "pattern": "^[a-z][a-z0-9-]{1,40}$"
      },
      "$comment": "Generics: system, system-mono, sans, serif, mono. The catalogue (ARCHITECTURE.md 1.5) says which ids are display-only."
    },
    "role": {
      "type": "object",
      "additionalProperties": false,
      "properties": {
        "size": {
          "type": "number",
          "minimum": 10,
          "maximum": 48
        },
        "line-height": {
          "type": "number",
          "minimum": 1.0,
          "maximum": 1.8,
          "description": "A multiple of size."
        },
        "weight": {
          "type": "integer",
          "minimum": 300,
          "maximum": 900,
          "multipleOf": 50
        },
        "tracking": {
          "type": "number",
          "minimum": -0.03,
          "maximum": 0.12,
          "description": "em"
        },
        "case": {
          "enum": [
            "as-written",
            "upper"
          ],
          "description": "upper is allowed on label and caption only, and needs tracking >= 0.04. Text that holds a name (a person, an app such as myAssistant, a calendar, a file) keeps its own case in every theme: widgets mark it, and the resolver never upper-cases it (decided 2026-10-23)."
        },
        "stack": {
          "enum": [
            "display",
            "body",
            "mono"
          ],
          "description": "Which font stack the role is set in. Default: display for display-xl, display-lg and title; body for heading, body, body-strong, label and caption (as design/tokens.json today); mono for mono. A display-only font is still refused under 16 px whatever the stack."
        }
      }
    },
    "type": {
      "type": "object",
      "additionalProperties": false,
      "properties": {
        "display": {
          "$ref": "#/$defs/fontStack"
        },
        "body": {
          "$ref": "#/$defs/fontStack"
        },
        "mono": {
          "$ref": "#/$defs/fontStack"
        },
        "base": {
          "type": "number",
          "minimum": 12,
          "maximum": 19,
          "description": "Desktop body size in logical px. Phones add 1 and never go under 16 in fields."
        },
        "ratio": {
          "type": "number",
          "minimum": 1.067,
          "maximum": 1.333,
          "description": "Modular scale for derived role sizes."
        },
        "numerals": {
          "enum": [
            "proportional",
            "tabular"
          ]
        },
        "secondary-italic": {
          "type": "boolean"
        },
        "roles": {
          "type": "object",
          "additionalProperties": false,
          "properties": {
            "display-xl": {
              "$ref": "#/$defs/role"
            },
            "display-lg": {
              "$ref": "#/$defs/role"
            },
            "title": {
              "$ref": "#/$defs/role"
            },
            "heading": {
              "$ref": "#/$defs/role"
            },
            "body": {
              "$ref": "#/$defs/role"
            },
            "body-strong": {
              "$ref": "#/$defs/role"
            },
            "label": {
              "$ref": "#/$defs/role"
            },
            "caption": {
              "$ref": "#/$defs/role"
            },
            "mono": {
              "$ref": "#/$defs/role"
            }
          }
        }
      }
    },
    "shape": {
      "type": "object",
      "additionalProperties": false,
      "properties": {
        "corners": {
          "enum": [
            "round",
            "continuous",
            "cut",
            "square"
          ],
          "description": "continuous = squircle-like (ContinuousRectangleBorder); cut = chamfer (BeveledRectangleBorder). square ignores the radii."
        },
        "radius": {
          "type": "object",
          "additionalProperties": false,
          "properties": {
            "xs": {
              "type": "number",
              "minimum": 0,
              "maximum": 8
            },
            "sm": {
              "type": "number",
              "minimum": 0,
              "maximum": 14
            },
            "md": {
              "type": "number",
              "minimum": 0,
              "maximum": 20
            },
            "lg": {
              "type": "number",
              "minimum": 0,
              "maximum": 28
            },
            "xl": {
              "type": "number",
              "minimum": 0,
              "maximum": 36
            }
          }
        },
        "controls": {
          "enum": [
            "pill",
            "match"
          ],
          "description": "pill: buttons, chips, switches and search fields are capsules. match: they use radius.sm."
        },
        "cut-size": {
          "type": "number",
          "minimum": 2,
          "maximum": 12,
          "description": "Chamfer length when corners is cut."
        }
      }
    },
    "densitySet": {
      "type": "object",
      "additionalProperties": false,
      "properties": {
        "control": {
          "type": "number",
          "minimum": 24,
          "maximum": 64
        },
        "row": {
          "type": "number",
          "minimum": 24,
          "maximum": 72
        },
        "icon": {
          "type": "number",
          "minimum": 14,
          "maximum": 28
        },
        "space": {
          "type": "number",
          "minimum": 0.75,
          "maximum": 1.5,
          "description": "Multiplier on the 4px spacing scale."
        }
      }
    },
    "density": {
      "type": "object",
      "additionalProperties": false,
      "description": "Per platform class. The runtime raises every value to the platform floor (24 desktop, 44 iOS, 48 Android, 44 for a coarse pointer), so no file can go below it.",
      "properties": {
        "preset": {
          "enum": [
            "compact",
            "regular",
            "roomy"
          ]
        },
        "desktop": {
          "$ref": "#/$defs/densitySet"
        },
        "phone": {
          "$ref": "#/$defs/densitySet"
        }
      }
    },
    "borders": {
      "type": "object",
      "additionalProperties": false,
      "properties": {
        "width": {
          "enum": [
            "hairline",
            1,
            2,
            3
          ]
        },
        "style": {
          "enum": [
            "solid",
            "dashed",
            "double"
          ],
          "description": "dashed and double apply to cards and separators; inputs and focus rings stay solid."
        },
        "colour": {
          "enum": [
            "line",
            "line-strong",
            "edge",
            "accent"
          ]
        },
        "cards": {
          "type": "boolean"
        },
        "controls": {
          "type": "boolean",
          "description": "Outline on buttons and fields. Inputs keep a 3:1 edge or underline whatever this says."
        },
        "separators": {
          "enum": [
            "none",
            "inset",
            "full"
          ]
        },
        "title-rule": {
          "enum": [
            "none",
            "single",
            "double"
          ]
        },
        "focus": {
          "enum": [
            "single",
            "double"
          ],
          "description": "The keyboard focus ring. single (the default): 2 px in focus, 2 px out, with a surface keyline in the gap only where the ring sits on a fill. double: 3 px in focus, 1 px out, with the surface keyline on every control (High Contrast). Both reach 4 px from the control."
        }
      }
    },
    "elevation": {
      "type": "object",
      "additionalProperties": false,
      "properties": {
        "style": {
          "enum": [
            "none",
            "soft",
            "hard",
            "offset",
            "bevel",
            "glow"
          ],
          "description": "glow lights the primary button and the selection marker only."
        },
        "strength": {
          "type": "number",
          "minimum": 0,
          "maximum": 1
        },
        "offset": {
          "type": "number",
          "minimum": 0,
          "maximum": 8,
          "description": "px, for hard and offset."
        },
        "press": {
          "enum": [
            "none",
            "collapse"
          ],
          "description": "collapse: a pressed hard or offset shadow drops to 0 (the control sinks)."
        }
      }
    },
    "gradient": {
      "type": "object",
      "additionalProperties": false,
      "description": "The style's gradient: its angle. The stops are colours and come from each palette (palettes[].gradient), or are derived from its seeds.",
      "properties": {
        "angle": {
          "type": "number",
          "minimum": 0,
          "maximum": 360
        }
      }
    },
    "pattern": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "kind"
      ],
      "properties": {
        "kind": {
          "enum": [
            "dots",
            "grid",
            "ruled",
            "margin-rule",
            "grain",
            "scanlines"
          ]
        },
        "spacing": {
          "type": "number",
          "minimum": 8,
          "maximum": 64
        },
        "opacity": {
          "type": "number",
          "minimum": 0.02,
          "maximum": 0.12
        },
        "colour": {
          "enum": [
            "line",
            "ink",
            "accent"
          ]
        }
      }
    },
    "image": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "light",
        "dark"
      ],
      "properties": {
        "light": {
          "type": "string",
          "pattern": "^images/[a-z0-9][a-z0-9-]{0,31}\\.(png|jpg)$"
        },
        "dark": {
          "type": "string",
          "pattern": "^images/[a-z0-9][a-z0-9-]{0,31}\\.(png|jpg)$"
        },
        "fit": {
          "enum": [
            "cover",
            "tile"
          ]
        },
        "opacity": {
          "type": "number",
          "minimum": 0.05,
          "maximum": 0.6
        },
        "tint-opacity": {
          "type": "number",
          "minimum": 0,
          "maximum": 0.9
        },
        "blur": {
          "type": "number",
          "minimum": 0,
          "maximum": 24,
          "description": "Applied once at import, never per frame."
        }
      }
    },
    "materials": {
      "type": "object",
      "additionalProperties": false,
      "properties": {
        "window": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "kind"
          ],
          "properties": {
            "kind": {
              "enum": [
                "solid",
                "gradient",
                "pattern",
                "image"
              ]
            },
            "gradient": {
              "$ref": "#/$defs/gradient"
            },
            "pattern": {
              "$ref": "#/$defs/pattern"
            },
            "image": {
              "$ref": "#/$defs/image"
            }
          },
          "allOf": [
            {
              "if": {
                "properties": {
                  "kind": {
                    "const": "gradient"
                  }
                }
              },
              "then": {
                "required": [
                  "gradient"
                ]
              }
            },
            {
              "if": {
                "properties": {
                  "kind": {
                    "const": "pattern"
                  }
                }
              },
              "then": {
                "required": [
                  "pattern"
                ]
              }
            },
            {
              "if": {
                "properties": {
                  "kind": {
                    "const": "image"
                  }
                }
              },
              "then": {
                "required": [
                  "image"
                ]
              }
            }
          ]
        },
        "sidebar": {
          "enum": [
            "solid",
            "translucent",
            "native"
          ],
          "description": "native: the window's own material on macOS, solid elsewhere."
        },
        "bars": {
          "enum": [
            "solid",
            "translucent",
            "blur"
          ],
          "description": "Toolbar and floating bars. blur: one shared BackdropGroup per window; solid on the web, with reduced transparency and on low-end devices."
        },
        "blur": {
          "type": "number",
          "minimum": 8,
          "maximum": 30
        }
      }
    },
    "icons": {
      "type": "object",
      "additionalProperties": false,
      "properties": {
        "set": {
          "enum": [
            "lucide",
            "phosphor",
            "tabler",
            "material-outlined",
            "material-rounded",
            "material-sharp",
            "pixelarticons",
            "iconoir"
          ]
        },
        "weight": {
          "enum": [
            "thin",
            "light",
            "regular",
            "bold",
            "fill"
          ],
          "description": "Mapped to the nearest weight the set has."
        },
        "selected": {
          "enum": [
            "same",
            "fill"
          ],
          "description": "fill: the current sidebar section's icon is filled where the set has a fill."
        },
        "tiles": {
          "enum": [
            "tinted",
            "outlined",
            "none"
          ]
        }
      }
    },
    "motion": {
      "type": "object",
      "additionalProperties": false,
      "properties": {
        "personality": {
          "enum": [
            "none",
            "calm",
            "standard",
            "crisp",
            "lively"
          ]
        },
        "scale": {
          "type": "number",
          "minimum": 0.5,
          "maximum": 1.5,
          "description": "Multiplies fast, base and slow; slow is capped at 500 ms."
        },
        "press": {
          "enum": [
            "none",
            "dim",
            "dim-scale",
            "sink",
            "invert"
          ]
        },
        "enter": {
          "enum": [
            "none",
            "fade",
            "fade-rise"
          ]
        }
      }
    },
    "components": {
      "type": "object",
      "additionalProperties": false,
      "properties": {
        "button": {
          "type": "object",
          "additionalProperties": false,
          "properties": {
            "primary": {
              "enum": [
                "filled",
                "outline",
                "brutal",
                "bevel",
                "push"
              ],
              "description": "Never text: a primary action must look like a button."
            },
            "secondary": {
              "enum": [
                "tonal",
                "outline",
                "text"
              ]
            },
            "plain": {
              "enum": [
                "text",
                "underline"
              ],
              "description": "A plain button (Cancel, Reject): its label alone, or its label underlined so it reads as an action where every other control is outlined (the accessibility themes). Default text."
            },
            "shape": {
              "enum": [
                "pill",
                "rounded",
                "square",
                "cut"
              ]
            }
          }
        },
        "list": {
          "enum": [
            "plain",
            "inset",
            "cards",
            "bordered",
            "ruled",
            "table"
          ]
        },
        "sidebar": {
          "enum": [
            "source-list",
            "column",
            "rail",
            "tabs"
          ]
        },
        "toolbar": {
          "enum": [
            "native",
            "flat",
            "floating"
          ]
        },
        "inputs": {
          "enum": [
            "filled",
            "outlined",
            "underlined"
          ]
        },
        "selection": {
          "enum": [
            "tint",
            "solid",
            "inverse",
            "bar",
            "outline",
            "highlighter"
          ]
        },
        "avatar": {
          "enum": [
            "circle",
            "rounded",
            "square",
            "shape",
            "none"
          ]
        },
        "tabs": {
          "enum": [
            "pill",
            "underline",
            "boxed"
          ]
        },
        "chat": {
          "enum": [
            "bubbles",
            "blocks",
            "transcript"
          ]
        },
        "month": {
          "enum": [
            "boxed",
            "open",
            "table"
          ]
        },
        "today": {
          "enum": [
            "disc",
            "ring",
            "inverse"
          ]
        },
        "data-colours": {
          "enum": [
            "colour",
            "pattern"
          ],
          "description": "pattern: calendar colours become greys with a pattern and the name always shows (E-ink)."
        }
      }
    }
  }
}
''';

/// The built-in themes, each `design/themes/<slug>/theme.json` byte for byte, by id, in the gallery's order:
/// System, then Kiwi, Hairline, Frosted, Journal, Sticker, Paperback, High Contrast, E Ink, Large.
const builtInThemeJson = {
  'mydata.system': r'''{
  "format": 1,
  "id": "mydata.system",
  "name": "System",
  "version": "1.0.0",
  "author": "myData",
  "licence": "CC0-1.0",
  "description": "The platform's own look: the Mac shell on macOS, Material 3 with the wallpaper's colours on Android. On Windows, Linux and the web, Kiwi in the platform's font until that platform's own pass.",
  "frame": "system",
  "preview": {
    "blurb": "Looks like the rest of your computer.",
    "scene": "contacts"
  },
  "sound": "none"
}
''',
  'mydata.kiwi': r'''{
  "format": 1,
  "id": "mydata.kiwi",
  "name": "Kiwi",
  "version": "1.0.0",
  "author": "myData",
  "licence": "CC0-1.0",
  "description": "Soft grey grounds, white cards, continuous rounded corners, pills, tinted tiles and one accent colour. The house style, as a whole language.",
  "frame": "drawn",
  "preview": {
    "blurb": "Soft and airy, with glass bars.",
    "scene": "contacts"
  },
  "palettes": [
    {
      "id": "kiwi",
      "name": "Kiwi",
      "light": {
        "bg": "#F6F6F5",
        "surface": "#FFFFFF",
        "ink": "#1A1A19",
        "ink-muted": "#5C5C58",
        "accent": "#4C7814",
        "on-accent": "#FFFFFF"
      },
      "dark": {
        "bg": "#111111",
        "surface": "#1A1A1A",
        "ink": "#EDEDEB",
        "ink-muted": "#A8A8A4",
        "accent": "#A9CC4E",
        "on-accent": "#1A2408"
      },
      "overrides": {
        "light": {
          "surface-raised": "#FFFFFF",
          "surface-sunken": "#EDEDEB",
          "surface-hover": "#D9D9D6",
          "line": "#E3E3E0",
          "line-strong": "#83837E",
          "edge": "#1A1A19",
          "accent-soft": "#EBF3DA",
          "link": "#4B7611",
          "selection": "#4C7814",
          "on-selection": "#FFFFFF",
          "selection-inactive": "#EDEDEB",
          "focus": "#B3261E",
          "focus-on-danger": "#1A1A19",
          "success": "#256B29",
          "success-soft": "#DDF2DF",
          "warning": "#8A5100",
          "warning-soft": "#FBEBCF",
          "danger": "#B3261E",
          "danger-soft": "#FBE0DD",
          "on-danger": "#FFFFFF",
          "info": "#1F5FA8",
          "info-soft": "#DCE9F8",
          "avatar-fill": "#E0E0DD",
          "data-red": "#D34730",
          "data-orange": "#EA700F",
          "data-yellow": "#E7BD1B",
          "data-green": "#36A462",
          "data-blue": "#159CE2",
          "data-purple": "#8B51E1",
          "data-brown": "#8A6859",
          "data-grey": "#939393",
          "scrim": "#14141459",
          "glass-fill": "#FFFFFFD0",
          "glass-stroke": "#FFFFFFCC",
          "shadow": "#141414"
        },
        "dark": {
          "surface-raised": "#232323",
          "surface-sunken": "#0B0B0B",
          "surface-hover": "#383838",
          "line": "#2E2E2E",
          "line-strong": "#7C7C7C",
          "edge": "#EDEDEB",
          "accent-soft": "#28331A",
          "link": "#A9CC4E",
          "selection": "#A9CC4E",
          "on-selection": "#1A2408",
          "selection-inactive": "#0B0B0B",
          "focus": "#F2867E",
          "focus-on-danger": "#EDEDEB",
          "success": "#7BC67E",
          "success-soft": "#1C3A1F",
          "warning": "#F0B45A",
          "warning-soft": "#3D2C0C",
          "danger": "#F2867E",
          "danger-soft": "#45191A",
          "on-danger": "#2B0B08",
          "info": "#8AB8EA",
          "info-soft": "#17304D",
          "avatar-fill": "#333333",
          "data-red": "#D34730",
          "data-orange": "#EA700F",
          "data-yellow": "#E7BD1B",
          "data-green": "#36A462",
          "data-blue": "#159CE2",
          "data-purple": "#8B51E1",
          "data-brown": "#8A6859",
          "data-grey": "#939393",
          "scrim": "#00000099",
          "glass-fill": "#1A1A1AD5",
          "glass-stroke": "#FFFFFF1F",
          "shadow": "#000000"
        }
      }
    },
    {
      "id": "sky",
      "name": "Sky",
      "light": {
        "bg": "#F6F6F5",
        "surface": "#FFFFFF",
        "ink": "#1A1A19",
        "ink-muted": "#5C5C58",
        "accent": "#1666AA",
        "on-accent": "#FFFFFF"
      },
      "dark": {
        "bg": "#111111",
        "surface": "#1A1A1A",
        "ink": "#EDEDEB",
        "ink-muted": "#A8A8A4",
        "accent": "#78BFF9",
        "on-accent": "#0B1F38"
      },
      "overrides": {
        "light": {
          "surface-raised": "#FFFFFF",
          "surface-sunken": "#EDEDEB",
          "surface-hover": "#D9D9D6",
          "line": "#E3E3E0",
          "line-strong": "#83837E",
          "edge": "#1A1A19",
          "accent-soft": "#DFF1FF",
          "link": "#1666AA",
          "selection": "#1666AA",
          "on-selection": "#FFFFFF",
          "selection-inactive": "#EDEDEB",
          "focus": "#B3261E",
          "focus-on-danger": "#1A1A19",
          "success": "#256B29",
          "success-soft": "#DDF2DF",
          "warning": "#8A5100",
          "warning-soft": "#FBEBCF",
          "danger": "#B3261E",
          "danger-soft": "#FBE0DD",
          "on-danger": "#FFFFFF",
          "info": "#1F5FA8",
          "info-soft": "#DCE9F8",
          "avatar-fill": "#E0E0DD",
          "data-red": "#D34730",
          "data-orange": "#EA700F",
          "data-yellow": "#E7BD1B",
          "data-green": "#36A462",
          "data-blue": "#159CE2",
          "data-purple": "#8B51E1",
          "data-brown": "#8A6859",
          "data-grey": "#939393",
          "scrim": "#14141459",
          "glass-fill": "#FFFFFFD0",
          "glass-stroke": "#FFFFFFCC",
          "shadow": "#141414"
        },
        "dark": {
          "surface-raised": "#232323",
          "surface-sunken": "#0B0B0B",
          "surface-hover": "#383838",
          "line": "#2E2E2E",
          "line-strong": "#7C7C7C",
          "edge": "#EDEDEB",
          "accent-soft": "#21303E",
          "link": "#78BFF9",
          "selection": "#78BFF9",
          "on-selection": "#0B1F38",
          "selection-inactive": "#0B0B0B",
          "focus": "#F2867E",
          "focus-on-danger": "#EDEDEB",
          "success": "#7BC67E",
          "success-soft": "#1C3A1F",
          "warning": "#F0B45A",
          "warning-soft": "#3D2C0C",
          "danger": "#F2867E",
          "danger-soft": "#45191A",
          "on-danger": "#2B0B08",
          "info": "#8AB8EA",
          "info-soft": "#17304D",
          "avatar-fill": "#333333",
          "data-red": "#D34730",
          "data-orange": "#EA700F",
          "data-yellow": "#E7BD1B",
          "data-green": "#36A462",
          "data-blue": "#159CE2",
          "data-purple": "#8B51E1",
          "data-brown": "#8A6859",
          "data-grey": "#939393",
          "scrim": "#00000099",
          "glass-fill": "#1A1A1AD5",
          "glass-stroke": "#FFFFFF1F",
          "shadow": "#000000"
        }
      }
    },
    {
      "id": "violet",
      "name": "Violet",
      "light": {
        "bg": "#F6F6F5",
        "surface": "#FFFFFF",
        "ink": "#1A1A19",
        "ink-muted": "#5C5C58",
        "accent": "#6849AB",
        "on-accent": "#FFFFFF"
      },
      "dark": {
        "bg": "#111111",
        "surface": "#1A1A1A",
        "ink": "#EDEDEB",
        "ink-muted": "#A8A8A4",
        "accent": "#BCA9F7",
        "on-accent": "#24113D"
      },
      "overrides": {
        "light": {
          "surface-raised": "#FFFFFF",
          "surface-sunken": "#EDEDEB",
          "surface-hover": "#D9D9D6",
          "line": "#E3E3E0",
          "line-strong": "#83837E",
          "edge": "#1A1A19",
          "accent-soft": "#F0EAFF",
          "link": "#6849AB",
          "selection": "#6849AB",
          "on-selection": "#FFFFFF",
          "selection-inactive": "#EDEDEB",
          "focus": "#B3261E",
          "focus-on-danger": "#1A1A19",
          "success": "#256B29",
          "success-soft": "#DDF2DF",
          "warning": "#8A5100",
          "warning-soft": "#FBEBCF",
          "danger": "#B3261E",
          "danger-soft": "#FBE0DD",
          "on-danger": "#FFFFFF",
          "info": "#1F5FA8",
          "info-soft": "#DCE9F8",
          "avatar-fill": "#E0E0DD",
          "data-red": "#D34730",
          "data-orange": "#EA700F",
          "data-yellow": "#E7BD1B",
          "data-green": "#36A462",
          "data-blue": "#159CE2",
          "data-purple": "#8B51E1",
          "data-brown": "#8A6859",
          "data-grey": "#939393",
          "scrim": "#14141459",
          "glass-fill": "#FFFFFFD0",
          "glass-stroke": "#FFFFFFCC",
          "shadow": "#141414"
        },
        "dark": {
          "surface-raised": "#232323",
          "surface-sunken": "#0B0B0B",
          "surface-hover": "#383838",
          "line": "#2E2E2E",
          "line-strong": "#7C7C7C",
          "edge": "#EDEDEB",
          "accent-soft": "#302C3D",
          "link": "#BCA9F7",
          "selection": "#BCA9F7",
          "on-selection": "#24113D",
          "selection-inactive": "#0B0B0B",
          "focus": "#F2867E",
          "focus-on-danger": "#EDEDEB",
          "success": "#7BC67E",
          "success-soft": "#1C3A1F",
          "warning": "#F0B45A",
          "warning-soft": "#3D2C0C",
          "danger": "#F2867E",
          "danger-soft": "#45191A",
          "on-danger": "#2B0B08",
          "info": "#8AB8EA",
          "info-soft": "#17304D",
          "avatar-fill": "#333333",
          "data-red": "#D34730",
          "data-orange": "#EA700F",
          "data-yellow": "#E7BD1B",
          "data-green": "#36A462",
          "data-blue": "#159CE2",
          "data-purple": "#8B51E1",
          "data-brown": "#8A6859",
          "data-grey": "#939393",
          "scrim": "#00000099",
          "glass-fill": "#1A1A1AD5",
          "glass-stroke": "#FFFFFF1F",
          "shadow": "#000000"
        }
      }
    }
  ],
  "default-palette": "kiwi",
  "colour-use": {
    "same-as": {
      "sidebar": "bg",
      "toolbar": "bg"
    }
  },
  "type": {
    "display": [
      "plus-jakarta-sans",
      "sans"
    ],
    "body": [
      "figtree",
      "sans"
    ],
    "mono": [
      "jetbrains-mono",
      "mono"
    ],
    "base": 15,
    "ratio": 1.2,
    "numerals": "proportional",
    "secondary-italic": false,
    "roles": {
      "display-xl": {
        "size": 40,
        "line-height": 1.15,
        "weight": 700,
        "tracking": -0.02
      },
      "display-lg": {
        "size": 30,
        "line-height": 1.2,
        "weight": 700,
        "tracking": -0.02
      },
      "title": {
        "size": 22,
        "line-height": 1.2727,
        "weight": 700,
        "tracking": -0.01
      },
      "heading": {
        "size": 17,
        "line-height": 1.4118,
        "weight": 600,
        "tracking": 0
      },
      "body": {
        "size": 15,
        "line-height": 1.4667,
        "weight": 400,
        "tracking": 0
      },
      "body-strong": {
        "size": 15,
        "line-height": 1.4667,
        "weight": 600,
        "tracking": 0
      },
      "label": {
        "size": 13,
        "line-height": 1.3846,
        "weight": 600,
        "tracking": 0
      },
      "caption": {
        "size": 13,
        "line-height": 1.3846,
        "weight": 400,
        "tracking": 0
      },
      "mono": {
        "size": 13,
        "line-height": 1.5385,
        "weight": 400,
        "tracking": 0
      }
    }
  },
  "shape": {
    "corners": "continuous",
    "radius": {
      "xs": 6,
      "sm": 10,
      "md": 14,
      "lg": 20,
      "xl": 28
    },
    "controls": "pill"
  },
  "density": {
    "desktop": {
      "control": 44,
      "row": 56,
      "icon": 20,
      "space": 1
    },
    "phone": {
      "control": 44,
      "row": 56,
      "icon": 20,
      "space": 1
    }
  },
  "borders": {
    "width": 1,
    "style": "solid",
    "colour": "line",
    "cards": false,
    "controls": false,
    "separators": "full",
    "title-rule": "none"
  },
  "elevation": {
    "style": "soft",
    "strength": 0.5,
    "offset": 0,
    "press": "none"
  },
  "materials": {
    "window": {
      "kind": "solid"
    },
    "sidebar": "solid",
    "bars": "blur",
    "blur": 24
  },
  "icons": {
    "set": "lucide",
    "weight": "regular",
    "selected": "same",
    "tiles": "tinted"
  },
  "motion": {
    "personality": "standard",
    "scale": 1,
    "press": "dim-scale",
    "enter": "fade-rise"
  },
  "components": {
    "button": {
      "primary": "filled",
      "secondary": "tonal",
      "plain": "text",
      "shape": "pill"
    },
    "list": "inset",
    "sidebar": "column",
    "toolbar": "flat",
    "inputs": "outlined",
    "selection": "tint",
    "avatar": "circle",
    "tabs": "pill",
    "chat": "bubbles",
    "month": "boxed",
    "today": "disc",
    "data-colours": "colour"
  },
  "illustration": "flat",
  "sound": "none"
}
''',
  'mydata.hairline': r'''{
  "format": 1,
  "id": "mydata.hairline",
  "name": "Hairline",
  "version": "1.0.0",
  "author": "myData",
  "licence": "CC0-1.0",
  "description": "A quiet, precise tool: Inter, hairlines, small corners, no tiles, an ink bar on the selected row and crisp motion.",
  "frame": "drawn",
  "preview": {
    "blurb": "Precise and quiet: hairlines, small corners.",
    "scene": "contacts"
  },
  "palettes": [
    {
      "id": "graphite",
      "name": "Graphite",
      "light": {
        "bg": "#F4F4F2",
        "surface": "#FFFFFF",
        "ink": "#161616",
        "ink-muted": "#595957",
        "accent": "#232323",
        "on-accent": "#FFFFFF"
      },
      "dark": {
        "bg": "#141414",
        "surface": "#1C1C1C",
        "ink": "#E8E8E6",
        "ink-muted": "#A3A3A0",
        "accent": "#E6E6E4",
        "on-accent": "#161616"
      },
      "overrides": {
        "light": {
          "surface-raised": "#FFFFFF",
          "surface-sunken": "#EBEBE8",
          "surface-hover": "#D7D7D7",
          "sidebar": "#EDEDEA",
          "toolbar": "#F4F4F2",
          "line": "#E0E0DC",
          "line-strong": "#878783",
          "accent-soft": "#E7E7E4",
          "link": "#232323",
          "on-selection": "#FFFFFF",
          "selection-inactive": "#EBEBE8",
          "focus": "#B3261E",
          "focus-on-danger": "#161616",
          "success": "#256B29",
          "success-soft": "#DDF2DF",
          "warning": "#8A5100",
          "warning-soft": "#FBEBCF",
          "danger": "#B3261E",
          "danger-soft": "#FBE0DD",
          "on-danger": "#FFFFFF",
          "info": "#1F5FA8",
          "info-soft": "#DCE9F8",
          "data-red": "#D34730",
          "data-orange": "#EA700F",
          "data-yellow": "#E7BD1B",
          "data-green": "#36A462",
          "data-blue": "#159CE2",
          "data-purple": "#8B51E1",
          "data-brown": "#8A6859",
          "data-grey": "#939393",
          "scrim": "#14141459",
          "glass-fill": "#FFFFFFB8",
          "glass-stroke": "#FFFFFFCC",
          "shadow": "#141414"
        },
        "dark": {
          "surface-raised": "#242424",
          "surface-sunken": "#0F0F0F",
          "surface-hover": "#373736",
          "sidebar": "#181818",
          "toolbar": "#141414",
          "line": "#2E2E2E",
          "line-strong": "#7A7A7A",
          "accent-soft": "#2C2C2C",
          "link": "#E6E6E4",
          "on-selection": "#161616",
          "selection-inactive": "#262626",
          "focus": "#F2867E",
          "focus-on-danger": "#E8E8E6",
          "success": "#7BC67E",
          "success-soft": "#1C3A1F",
          "warning": "#F0B45A",
          "warning-soft": "#3D2C0C",
          "danger": "#F2867E",
          "danger-soft": "#45191A",
          "on-danger": "#2B0B08",
          "info": "#8AB8EA",
          "info-soft": "#17304D",
          "data-red": "#D34730",
          "data-orange": "#EA700F",
          "data-yellow": "#E7BD1B",
          "data-green": "#36A462",
          "data-blue": "#159CE2",
          "data-purple": "#8B51E1",
          "data-brown": "#8A6859",
          "data-grey": "#939393",
          "scrim": "#00000099",
          "glass-fill": "#1A1A1AB8",
          "glass-stroke": "#FFFFFF1F",
          "shadow": "#000000"
        }
      },
      "contrast": {
        "light": {
          "ink-muted": "#41413F",
          "line-strong": "#6F6F6C",
          "line": "#8A8A86",
          "danger": "#9A0001",
          "success": "#105A18",
          "warning": "#784000",
          "info": "#024A92"
        },
        "dark": {
          "ink-muted": "#C8C8C5",
          "line-strong": "#848484",
          "line": "#7A7A7A",
          "danger": "#FF958C",
          "success": "#88D48B",
          "info": "#92C0F2"
        }
      }
    },
    {
      "id": "slate",
      "name": "Slate",
      "light": {
        "bg": "#EFF4FB",
        "surface": "#FCFFFF",
        "ink": "#14161A",
        "ink-muted": "#55595F",
        "accent": "#364E6D",
        "on-accent": "#FFFFFF"
      },
      "dark": {
        "bg": "#111419",
        "surface": "#191C21",
        "ink": "#E2E9F1",
        "ink-muted": "#9DA4AC",
        "accent": "#BACCE5",
        "on-accent": "#141A22"
      },
      "overrides": {
        "light": {
          "surface-raised": "#FCFFFF",
          "surface-sunken": "#E6EBF3",
          "surface-hover": "#D4D7DC",
          "sidebar": "#E8EDF5",
          "toolbar": "#EFF4FB",
          "line": "#DAE0E9",
          "line-strong": "#81878F",
          "accent-soft": "#E0E8F1",
          "link": "#364E6D",
          "on-selection": "#FFFFFF",
          "selection-inactive": "#E6EBF3",
          "focus": "#B3261E",
          "focus-on-danger": "#161616",
          "success": "#256B29",
          "success-soft": "#DDF2DF",
          "warning": "#8A5100",
          "warning-soft": "#FBEBCF",
          "danger": "#B3261E",
          "danger-soft": "#FBE0DD",
          "on-danger": "#FFFFFF",
          "info": "#1F5FA8",
          "info-soft": "#DCE9F8",
          "data-red": "#D34730",
          "data-orange": "#EA700F",
          "data-yellow": "#E7BD1B",
          "data-green": "#36A462",
          "data-blue": "#159CE2",
          "data-purple": "#8B51E1",
          "data-brown": "#8A6859",
          "data-grey": "#939393",
          "scrim": "#14141459",
          "glass-fill": "#FCFFFFB8",
          "glass-stroke": "#FFFFFFCC",
          "shadow": "#141414"
        },
        "dark": {
          "surface-raised": "#212429",
          "surface-sunken": "#0C0F13",
          "surface-hover": "#33373D",
          "sidebar": "#15181D",
          "toolbar": "#111419",
          "line": "#2B2E33",
          "line-strong": "#767B80",
          "accent-soft": "#282C32",
          "link": "#BACCE5",
          "on-selection": "#141A22",
          "selection-inactive": "#23262B",
          "focus": "#F2867E",
          "focus-on-danger": "#E8E8E6",
          "success": "#7BC67E",
          "success-soft": "#1C3A1F",
          "warning": "#F0B45A",
          "warning-soft": "#3D2C0C",
          "danger": "#F2867E",
          "danger-soft": "#45191A",
          "on-danger": "#2B0B08",
          "info": "#8AB8EA",
          "info-soft": "#17304D",
          "data-red": "#D34730",
          "data-orange": "#EA700F",
          "data-yellow": "#E7BD1B",
          "data-green": "#36A462",
          "data-blue": "#159CE2",
          "data-purple": "#8B51E1",
          "data-brown": "#8A6859",
          "data-grey": "#939393",
          "scrim": "#00000099",
          "glass-fill": "#171A1FB8",
          "glass-stroke": "#FFFFFF1F",
          "shadow": "#000000"
        }
      },
      "contrast": {
        "light": {
          "ink-muted": "#3D4147",
          "line-strong": "#6A6F76",
          "line": "#848A92",
          "danger": "#9A0001",
          "success": "#105A18",
          "warning": "#784000",
          "info": "#024A92",
          "link": "#344C6B"
        },
        "dark": {
          "ink-muted": "#C2C9D1",
          "line-strong": "#80858A",
          "line": "#767B80",
          "danger": "#FF958C",
          "success": "#88D48B",
          "info": "#92C0F2"
        }
      }
    },
    {
      "id": "cobalt",
      "name": "Cobalt",
      "light": {
        "bg": "#F4F4F2",
        "surface": "#FFFFFF",
        "ink": "#161616",
        "ink-muted": "#595957",
        "accent": "#1D4BC0",
        "on-accent": "#FFFFFF"
      },
      "dark": {
        "bg": "#141414",
        "surface": "#1C1C1C",
        "ink": "#E8E8E6",
        "ink-muted": "#A3A3A0",
        "accent": "#8AB4FF",
        "on-accent": "#0A1838"
      },
      "overrides": {
        "light": {
          "surface-raised": "#FFFFFF",
          "surface-sunken": "#EBEBE8",
          "surface-hover": "#D7D7D7",
          "sidebar": "#EDEDEA",
          "toolbar": "#F4F4F2",
          "line": "#E0E0DC",
          "line-strong": "#878783",
          "accent-soft": "#D7E7FF",
          "link": "#1D4BC0",
          "on-selection": "#FFFFFF",
          "selection-inactive": "#EBEBE8",
          "focus": "#B3261E",
          "focus-on-danger": "#161616",
          "success": "#256B29",
          "success-soft": "#DDF2DF",
          "warning": "#8A5100",
          "warning-soft": "#FBEBCF",
          "danger": "#B3261E",
          "danger-soft": "#FBE0DD",
          "on-danger": "#FFFFFF",
          "info": "#1F5FA8",
          "info-soft": "#DCE9F8",
          "data-red": "#D34730",
          "data-orange": "#EA700F",
          "data-yellow": "#E7BD1B",
          "data-green": "#36A462",
          "data-blue": "#159CE2",
          "data-purple": "#8B51E1",
          "data-brown": "#8A6859",
          "data-grey": "#939393",
          "scrim": "#14141459",
          "glass-fill": "#FFFFFFB8",
          "glass-stroke": "#FFFFFFCC",
          "shadow": "#141414"
        },
        "dark": {
          "surface-raised": "#242424",
          "surface-sunken": "#0F0F0F",
          "surface-hover": "#373736",
          "sidebar": "#181818",
          "toolbar": "#141414",
          "line": "#2E2E2E",
          "line-strong": "#7A7A7A",
          "accent-soft": "#242C3B",
          "link": "#8AB4FF",
          "on-selection": "#0A1838",
          "selection-inactive": "#262626",
          "focus": "#F2867E",
          "focus-on-danger": "#E8E8E6",
          "success": "#7BC67E",
          "success-soft": "#1C3A1F",
          "warning": "#F0B45A",
          "warning-soft": "#3D2C0C",
          "danger": "#F2867E",
          "danger-soft": "#45191A",
          "on-danger": "#2B0B08",
          "info": "#8AB8EA",
          "info-soft": "#17304D",
          "data-red": "#D34730",
          "data-orange": "#EA700F",
          "data-yellow": "#E7BD1B",
          "data-green": "#36A462",
          "data-blue": "#159CE2",
          "data-purple": "#8B51E1",
          "data-brown": "#8A6859",
          "data-grey": "#939393",
          "scrim": "#00000099",
          "glass-fill": "#1A1A1AB8",
          "glass-stroke": "#FFFFFF1F",
          "shadow": "#000000"
        }
      },
      "contrast": {
        "light": {
          "ink-muted": "#41413F",
          "line-strong": "#6F6F6C",
          "line": "#8A8A86",
          "danger": "#9A0001",
          "success": "#105A18",
          "warning": "#784000",
          "info": "#024A92",
          "link": "#133FB3",
          "accent": "#1A48BD"
        },
        "dark": {
          "ink-muted": "#C8C8C5",
          "line-strong": "#848484",
          "line": "#7A7A7A",
          "danger": "#FF958C",
          "success": "#88D48B",
          "info": "#92C0F2",
          "link": "#8FB9FF"
        }
      }
    }
  ],
  "default-palette": "graphite",
  "colour-use": {
    "same-as": {
      "selection": "ink",
      "edge": "ink",
      "avatar-fill": "surface"
    }
  },
  "type": {
    "display": [
      "inter",
      "sans"
    ],
    "body": [
      "inter",
      "sans"
    ],
    "mono": [
      "jetbrains-mono",
      "mono"
    ],
    "base": 14,
    "ratio": 1.2,
    "numerals": "tabular",
    "secondary-italic": false,
    "roles": {
      "display-xl": {
        "size": 32,
        "line-height": 1.15,
        "weight": 600,
        "tracking": -0.02
      },
      "display-lg": {
        "size": 26,
        "line-height": 1.2,
        "weight": 600,
        "tracking": -0.02
      },
      "title": {
        "size": 20,
        "line-height": 1.25,
        "weight": 600,
        "tracking": -0.015
      },
      "heading": {
        "size": 15,
        "line-height": 1.3,
        "weight": 600,
        "tracking": -0.01
      },
      "body": {
        "size": 14,
        "line-height": 1.43,
        "weight": 400,
        "tracking": 0
      },
      "body-strong": {
        "size": 14,
        "line-height": 1.43,
        "weight": 550,
        "tracking": 0
      },
      "label": {
        "size": 12,
        "line-height": 1.3,
        "weight": 500,
        "tracking": 0.01
      },
      "caption": {
        "size": 12,
        "line-height": 1.35,
        "weight": 400,
        "tracking": 0
      },
      "mono": {
        "size": 12.5,
        "line-height": 1.4,
        "weight": 400,
        "tracking": 0
      }
    }
  },
  "shape": {
    "corners": "round",
    "radius": {
      "xs": 3,
      "sm": 5,
      "md": 6,
      "lg": 8,
      "xl": 10
    },
    "controls": "match"
  },
  "density": {
    "desktop": {
      "control": 30,
      "row": 40,
      "icon": 16,
      "space": 0.85
    },
    "phone": {
      "control": 48,
      "row": 56,
      "icon": 22,
      "space": 1
    }
  },
  "borders": {
    "width": 1,
    "style": "solid",
    "colour": "line",
    "cards": true,
    "controls": true,
    "separators": "full",
    "title-rule": "none"
  },
  "elevation": {
    "style": "none",
    "strength": 0,
    "press": "none"
  },
  "materials": {
    "window": {
      "kind": "solid"
    },
    "sidebar": "solid",
    "bars": "solid"
  },
  "icons": {
    "set": "tabler",
    "weight": "light",
    "selected": "same",
    "tiles": "none"
  },
  "motion": {
    "personality": "crisp",
    "scale": 0.8,
    "press": "dim",
    "enter": "fade"
  },
  "components": {
    "button": {
      "primary": "filled",
      "secondary": "outline",
      "plain": "text",
      "shape": "rounded"
    },
    "list": "plain",
    "sidebar": "column",
    "toolbar": "flat",
    "inputs": "outlined",
    "selection": "bar",
    "avatar": "circle",
    "tabs": "underline",
    "chat": "blocks",
    "month": "open",
    "today": "disc",
    "data-colours": "colour"
  },
  "illustration": "line",
  "sound": "none"
}
''',
  'mydata.frosted': r'''{
  "format": 1,
  "id": "mydata.frosted",
  "name": "Frosted",
  "version": "1.0.0",
  "author": "myData",
  "licence": "CC0-1.0",
  "description": "Frosted glass over a static gradient sky: translucent bars and panels, round soft shapes and slow, calm eases.",
  "frame": "drawn",
  "preview": {
    "blurb": "A sky behind frosted glass.",
    "scene": "assistant"
  },
  "palettes": [
    {
      "id": "dusk",
      "name": "Dusk",
      "light": {
        "bg": "#E9EDF8",
        "surface": "#F3F5FB",
        "ink": "#141A2E",
        "ink-muted": "#4A5370",
        "accent": "#3D5AA9",
        "on-accent": "#FFFFFF"
      },
      "dark": {
        "bg": "#0E1326",
        "surface": "#1B2140",
        "ink": "#E8ECFA",
        "ink-muted": "#A9B3D6",
        "accent": "#9DB4F2",
        "on-accent": "#0E1A3A"
      },
      "overrides": {
        "light": {
          "surface-raised": "#FAFBFE",
          "surface-sunken": "#DCE0EC",
          "surface-hover": "#CDD0D8",
          "sidebar": "#E2E7F6",
          "toolbar": "#F3F5FB",
          "line": "#D6DCEE",
          "line-strong": "#81838C",
          "edge": "#141A2E",
          "accent-soft": "#DFE5F6",
          "link": "#3D5AA9",
          "selection": "#3D5AA9",
          "on-selection": "#FFFFFF",
          "selection-inactive": "#DCE0EC",
          "focus": "#B3261E",
          "focus-on-danger": "#141A2E",
          "success": "#256B29",
          "success-soft": "#D6E2DE",
          "warning": "#8A5100",
          "warning-soft": "#E4DED8",
          "danger": "#B3261E",
          "danger-soft": "#EAD8DC",
          "on-danger": "#FFFFFF",
          "info": "#1F5FA8",
          "info-soft": "#D5E0EF",
          "avatar-fill": "#D3DAF0",
          "data-red": "#D34730",
          "data-orange": "#DE6A0E",
          "data-yellow": "#E7BD1B",
          "data-green": "#349F5F",
          "data-blue": "#1494D7",
          "data-purple": "#8B51E1",
          "data-brown": "#8A6859",
          "data-grey": "#8C8C8C",
          "scrim": "#14141459",
          "glass-fill": "#F3F5FBCB",
          "glass-stroke": "#FFFFFFCC",
          "shadow": "#1B2450"
        },
        "dark": {
          "surface-raised": "#222951",
          "surface-sunken": "#1B2033",
          "surface-hover": "#383D5A",
          "sidebar": "#141A33",
          "toolbar": "#1B2140",
          "line": "#2A3155",
          "line-strong": "#70758D",
          "edge": "#E8ECFA",
          "accent-soft": "#283463",
          "link": "#9DB4F2",
          "selection": "#9DB4F2",
          "on-selection": "#0E1A3A",
          "selection-inactive": "#1B2033",
          "focus": "#F2867E",
          "focus-on-danger": "#E8ECFA",
          "success": "#7BC67E",
          "success-soft": "#32494F",
          "warning": "#F0B45A",
          "warning-soft": "#4E4446",
          "danger": "#F3928B",
          "danger-soft": "#4F394F",
          "on-danger": "#2C1A19",
          "info": "#8AB8EA",
          "info-soft": "#364569",
          "avatar-fill": "#2E3762",
          "data-red": "#D34730",
          "data-orange": "#EA700F",
          "data-yellow": "#E7BD1B",
          "data-green": "#36A462",
          "data-blue": "#159CE2",
          "data-purple": "#8B51E1",
          "data-brown": "#8A6859",
          "data-grey": "#939393",
          "scrim": "#00000099",
          "glass-fill": "#1B2140D3",
          "glass-stroke": "#FFFFFF1F",
          "shadow": "#000000"
        }
      },
      "gradient": {
        "light": [
          "#DDE4F8",
          "#E9E6F6",
          "#F5E6EE"
        ],
        "dark": [
          "#0E1326",
          "#1A1A40",
          "#2B1D48"
        ]
      }
    },
    {
      "id": "aurora",
      "name": "Aurora",
      "light": {
        "bg": "#E2F1F1",
        "surface": "#EFF7F7",
        "ink": "#002123",
        "ink-muted": "#305D5F",
        "accent": "#00736F",
        "on-accent": "#FFFFFF"
      },
      "dark": {
        "bg": "#00191D",
        "surface": "#002B31",
        "ink": "#DEF1F3",
        "ink-muted": "#8EBEC4",
        "accent": "#75D1C5",
        "on-accent": "#06262A"
      },
      "overrides": {
        "light": {
          "surface-raised": "#F8FCFC",
          "surface-sunken": "#D4E4E5",
          "surface-hover": "#C8D3D3",
          "sidebar": "#D8ECED",
          "toolbar": "#EFF7F7",
          "line": "#CAE2E3",
          "line-strong": "#7B8687",
          "edge": "#002123",
          "accent-soft": "#DAE9E8",
          "link": "#00706C",
          "selection": "#00736F",
          "on-selection": "#FFFFFF",
          "selection-inactive": "#D4E4E5",
          "focus": "#B3261E",
          "focus-on-danger": "#141A2E",
          "success": "#256B29",
          "success-soft": "#D6E2DE",
          "warning": "#8A5100",
          "warning-soft": "#E4DED8",
          "danger": "#B3261E",
          "danger-soft": "#EAD8DC",
          "on-danger": "#FFFFFF",
          "info": "#1F5FA8",
          "info-soft": "#D5E0EF",
          "avatar-fill": "#C4E1E3",
          "data-red": "#D34730",
          "data-orange": "#DE6A0E",
          "data-yellow": "#E7BD1B",
          "data-green": "#349F5F",
          "data-blue": "#1494D7",
          "data-purple": "#8B51E1",
          "data-brown": "#8A6859",
          "data-grey": "#8C8C8C",
          "scrim": "#14141459",
          "glass-fill": "#EFF7F7CD",
          "glass-stroke": "#FFFFFFCC",
          "shadow": "#1B2450"
        },
        "dark": {
          "surface-raised": "#00373E",
          "surface-sunken": "#06262A",
          "surface-hover": "#1A494E",
          "sidebar": "#002227",
          "toolbar": "#002B31",
          "line": "#003D44",
          "line-strong": "#5F7F83",
          "edge": "#DEF1F3",
          "accent-soft": "#00453D",
          "link": "#75D1C5",
          "selection": "#75D1C5",
          "on-selection": "#06262A",
          "selection-inactive": "#06262A",
          "focus": "#F2867E",
          "focus-on-danger": "#E8ECFA",
          "success": "#7BC67E",
          "success-soft": "#32494F",
          "warning": "#F0B45A",
          "warning-soft": "#4E4446",
          "danger": "#F3928B",
          "danger-soft": "#4F394F",
          "on-danger": "#2C1A19",
          "info": "#8AB8EA",
          "info-soft": "#364569",
          "avatar-fill": "#00454D",
          "data-red": "#D34730",
          "data-orange": "#EA700F",
          "data-yellow": "#E7BD1B",
          "data-green": "#36A462",
          "data-blue": "#159CE2",
          "data-purple": "#8B51E1",
          "data-brown": "#8A6859",
          "data-grey": "#939393",
          "scrim": "#00000099",
          "glass-fill": "#002B31D3",
          "glass-stroke": "#FFFFFF1F",
          "shadow": "#000000"
        }
      },
      "gradient": {
        "light": [
          "#D7EEEB",
          "#E1EAF4",
          "#EAE5F6"
        ],
        "dark": [
          "#0A1D22",
          "#10203A",
          "#1E1A3E"
        ]
      }
    },
    {
      "id": "sand",
      "name": "Sand",
      "light": {
        "bg": "#F3ECE4",
        "surface": "#F9F4F0",
        "ink": "#261807",
        "ink-muted": "#645039",
        "accent": "#8C541F",
        "on-accent": "#FFFFFF"
      },
      "dark": {
        "bg": "#1E1107",
        "surface": "#321F0E",
        "ink": "#F4EBE4",
        "ink-muted": "#C6B09E",
        "accent": "#E2B487",
        "on-accent": "#2E1A08"
      },
      "overrides": {
        "light": {
          "surface-raised": "#FDFBF8",
          "surface-sunken": "#E7DFD6",
          "surface-hover": "#D5CFC9",
          "sidebar": "#F0E6DA",
          "toolbar": "#F9F4F0",
          "line": "#E7DACD",
          "line-strong": "#88827C",
          "edge": "#261807",
          "accent-soft": "#EFE3DA",
          "link": "#8C541F",
          "selection": "#8C541F",
          "on-selection": "#FFFFFF",
          "selection-inactive": "#E7DFD6",
          "focus": "#2457C5",
          "focus-on-danger": "#141A2E",
          "success": "#256B29",
          "success-soft": "#D6E2DE",
          "warning": "#8A5100",
          "warning-soft": "#E4DED8",
          "danger": "#B3261E",
          "danger-soft": "#EAD8DC",
          "on-danger": "#FFFFFF",
          "info": "#1F5FA8",
          "info-soft": "#D5E0EF",
          "avatar-fill": "#E7D8C7",
          "data-red": "#D34730",
          "data-orange": "#DE6A0E",
          "data-yellow": "#E7BD1B",
          "data-green": "#349F5F",
          "data-blue": "#1494D7",
          "data-purple": "#8B51E1",
          "data-brown": "#8A6859",
          "data-grey": "#8C8C8C",
          "scrim": "#14141459",
          "glass-fill": "#F9F4F0CB",
          "glass-stroke": "#FFFFFFCC",
          "shadow": "#1B2450"
        },
        "dark": {
          "surface-raised": "#402611",
          "surface-sunken": "#2B1E15",
          "surface-hover": "#4D3B2C",
          "sidebar": "#28180B",
          "toolbar": "#321F0E",
          "line": "#452E1C",
          "line-strong": "#837367",
          "edge": "#F4EBE4",
          "accent-soft": "#512F05",
          "link": "#E2B487",
          "selection": "#E2B487",
          "on-selection": "#2E1A08",
          "selection-inactive": "#2B1E15",
          "focus": "#8CB4FF",
          "focus-on-danger": "#E8ECFA",
          "success": "#7BC67E",
          "success-soft": "#32494F",
          "warning": "#F0B45A",
          "warning-soft": "#4E4446",
          "danger": "#F3928B",
          "danger-soft": "#4F394F",
          "on-danger": "#2C1A19",
          "info": "#8AB8EA",
          "info-soft": "#364569",
          "avatar-fill": "#4F341D",
          "data-red": "#D34730",
          "data-orange": "#EA700F",
          "data-yellow": "#E7BD1B",
          "data-green": "#36A462",
          "data-blue": "#159CE2",
          "data-purple": "#8B51E1",
          "data-brown": "#8A6859",
          "data-grey": "#939393",
          "scrim": "#00000099",
          "glass-fill": "#321F0ED3",
          "glass-stroke": "#FFFFFF1F",
          "shadow": "#000000"
        }
      },
      "gradient": {
        "light": [
          "#F5E8D8",
          "#F3E4E4",
          "#E9E2EF"
        ],
        "dark": [
          "#1C1612",
          "#281C21",
          "#231D33"
        ]
      }
    }
  ],
  "default-palette": "dusk",
  "type": {
    "display": [
      "sora",
      "sans"
    ],
    "body": [
      "manrope",
      "sans"
    ],
    "mono": [
      "jetbrains-mono",
      "mono"
    ],
    "base": 15,
    "ratio": 1.25,
    "numerals": "proportional",
    "roles": {
      "display-xl": {
        "size": 40,
        "line-height": 1.15,
        "weight": 600,
        "tracking": -0.02
      },
      "display-lg": {
        "size": 30,
        "line-height": 1.2,
        "weight": 600,
        "tracking": -0.015
      },
      "title": {
        "size": 22,
        "line-height": 1.25,
        "weight": 600,
        "tracking": -0.01
      },
      "heading": {
        "size": 17,
        "line-height": 1.3,
        "weight": 600,
        "stack": "display"
      },
      "body": {
        "size": 15,
        "line-height": 1.5,
        "weight": 400
      },
      "body-strong": {
        "size": 15,
        "line-height": 1.5,
        "weight": 700
      },
      "label": {
        "size": 13,
        "line-height": 1.38,
        "weight": 600
      },
      "caption": {
        "size": 13,
        "line-height": 1.38,
        "weight": 400
      },
      "mono": {
        "size": 13,
        "line-height": 1.54,
        "weight": 400
      }
    }
  },
  "shape": {
    "corners": "continuous",
    "radius": {
      "xs": 6,
      "sm": 10,
      "md": 14,
      "lg": 18,
      "xl": 24
    },
    "controls": "pill"
  },
  "density": {
    "preset": "regular",
    "desktop": {
      "control": 36,
      "row": 48,
      "icon": 18,
      "space": 1.05
    }
  },
  "borders": {
    "width": "hairline",
    "style": "solid",
    "colour": "line",
    "cards": false,
    "controls": false,
    "separators": "inset",
    "title-rule": "none"
  },
  "elevation": {
    "style": "soft",
    "strength": 0.8,
    "press": "none"
  },
  "materials": {
    "window": {
      "kind": "gradient",
      "gradient": {
        "angle": 160
      }
    },
    "sidebar": "translucent",
    "bars": "blur",
    "blur": 24
  },
  "icons": {
    "set": "phosphor",
    "weight": "regular",
    "selected": "fill",
    "tiles": "tinted"
  },
  "motion": {
    "personality": "calm",
    "scale": 1.2,
    "press": "dim",
    "enter": "fade"
  },
  "components": {
    "button": {
      "primary": "filled",
      "secondary": "tonal",
      "plain": "text",
      "shape": "pill"
    },
    "list": "inset",
    "sidebar": "column",
    "toolbar": "floating",
    "inputs": "filled",
    "selection": "tint",
    "avatar": "circle",
    "tabs": "pill",
    "chat": "bubbles",
    "month": "open",
    "today": "ring",
    "data-colours": "colour"
  },
  "illustration": "line",
  "sound": "none"
}
''',
  'mydata.journal': r'''{
  "format": 1,
  "id": "mydata.journal",
  "name": "Journal",
  "version": "1.0.0",
  "author": "myData",
  "licence": "CC0-1.0",
  "description": "Editorial: a high-contrast serif for titles, ink rules instead of boxes, generous margins, no cards and few icons.",
  "frame": "drawn",
  "preview": {
    "blurb": "Set like a literary journal.",
    "scene": "contacts"
  },
  "palettes": [
    {
      "id": "plum",
      "name": "Plum",
      "light": {
        "bg": "#FBF8F4",
        "surface": "#FBF8F4",
        "ink": "#1C1420",
        "ink-muted": "#5E5463",
        "accent": "#7A3E8E",
        "on-accent": "#FFFFFF"
      },
      "dark": {
        "bg": "#17121A",
        "surface": "#17121A",
        "ink": "#EFE8F1",
        "ink-muted": "#B2A6B6",
        "accent": "#D2A6E0",
        "on-accent": "#2A0F33"
      },
      "overrides": {
        "light": {
          "surface-raised": "#FFFFFF",
          "surface-sunken": "#ECE8E6",
          "surface-hover": "#DDD9D7",
          "sidebar": "#F5F0EA",
          "line": "#D9D0D6",
          "line-strong": "#8E888D",
          "accent-soft": "#F1E4F5",
          "link": "#7A3E8E",
          "selection": "#7A3E8E",
          "on-selection": "#FFFFFF",
          "selection-inactive": "#ECE8E6",
          "focus": "#B3261E",
          "focus-on-danger": "#1C1420",
          "success": "#256B29",
          "success-soft": "#DFE5D8",
          "warning": "#8A5100",
          "warning-soft": "#EDE1D6",
          "danger": "#B3261E",
          "danger-soft": "#F5DED7",
          "on-danger": "#FFFFFF",
          "info": "#1F5FA8",
          "info-soft": "#DEE4EB",
          "avatar-fill": "#DDD9D7",
          "data-red": "#D34730",
          "data-orange": "#EA700F",
          "data-yellow": "#E7BD1B",
          "data-green": "#36A462",
          "data-blue": "#159CE2",
          "data-purple": "#8B51E1",
          "data-brown": "#8A6859",
          "data-grey": "#939393",
          "scrim": "#14141459",
          "glass-fill": "#FBF8F4B8",
          "glass-stroke": "#FFFFFFCC",
          "shadow": "#141414"
        },
        "dark": {
          "surface-raised": "#211A25",
          "surface-sunken": "#211C24",
          "surface-hover": "#363039",
          "sidebar": "#1C1620",
          "line": "#3A3040",
          "line-strong": "#6D6770",
          "accent-soft": "#3B2145",
          "link": "#D2A6E0",
          "selection": "#D2A6E0",
          "on-selection": "#2A0F33",
          "selection-inactive": "#211C24",
          "focus": "#F2867E",
          "focus-on-danger": "#EFE8F1",
          "success": "#7BC67E",
          "success-soft": "#303B33",
          "warning": "#F0B45A",
          "warning-soft": "#47372D",
          "danger": "#F2867E",
          "danger-soft": "#492D32",
          "on-danger": "#0A0302",
          "info": "#8AB8EA",
          "info-soft": "#333849",
          "avatar-fill": "#2C272F",
          "data-red": "#D34730",
          "data-orange": "#EA700F",
          "data-yellow": "#E7BD1B",
          "data-green": "#36A462",
          "data-blue": "#159CE2",
          "data-purple": "#8B51E1",
          "data-brown": "#8A6859",
          "data-grey": "#939393",
          "scrim": "#00000099",
          "glass-fill": "#17121AB8",
          "glass-stroke": "#FFFFFF1F",
          "shadow": "#000000"
        }
      }
    },
    {
      "id": "ink-blue",
      "name": "Ink blue",
      "light": {
        "bg": "#FBF8F4",
        "surface": "#FBF8F4",
        "ink": "#111824",
        "ink-muted": "#505968",
        "accent": "#20428D",
        "on-accent": "#FFFFFF"
      },
      "dark": {
        "bg": "#10141C",
        "surface": "#10141C",
        "ink": "#E6EBF5",
        "ink-muted": "#A2ABBC",
        "accent": "#99BCF5",
        "on-accent": "#0D1A3D"
      },
      "overrides": {
        "light": {
          "surface-raised": "#FFFFFF",
          "surface-sunken": "#ECE8E6",
          "surface-hover": "#DDD9D7",
          "sidebar": "#F5F0EA",
          "line": "#CFD3DC",
          "line-strong": "#878A91",
          "accent-soft": "#E0EAFB",
          "link": "#20428D",
          "selection": "#20428D",
          "on-selection": "#FFFFFF",
          "selection-inactive": "#ECE8E6",
          "focus": "#B3261E",
          "focus-on-danger": "#1C1420",
          "success": "#256B29",
          "success-soft": "#DFE5D8",
          "warning": "#8A5100",
          "warning-soft": "#EDE1D6",
          "danger": "#B3261E",
          "danger-soft": "#F5DED7",
          "on-danger": "#FFFFFF",
          "info": "#1F5FA8",
          "info-soft": "#DEE4EB",
          "avatar-fill": "#DDD9D7",
          "data-red": "#D34730",
          "data-orange": "#EA700F",
          "data-yellow": "#E7BD1B",
          "data-green": "#36A462",
          "data-blue": "#159CE2",
          "data-purple": "#8B51E1",
          "data-brown": "#8A6859",
          "data-grey": "#939393",
          "scrim": "#14141459",
          "glass-fill": "#FBF8F4B8",
          "glass-stroke": "#FFFFFFCC",
          "shadow": "#141414"
        },
        "dark": {
          "surface-raised": "#171D28",
          "surface-sunken": "#1A1E26",
          "surface-hover": "#2E333C",
          "sidebar": "#131923",
          "line": "#2C3545",
          "line-strong": "#656A73",
          "accent-soft": "#182D4F",
          "link": "#99BCF5",
          "selection": "#99BCF5",
          "on-selection": "#0D1A3D",
          "selection-inactive": "#1A1E26",
          "focus": "#F2867E",
          "focus-on-danger": "#EFE8F1",
          "success": "#7BC67E",
          "success-soft": "#303B33",
          "warning": "#F0B45A",
          "warning-soft": "#47372D",
          "danger": "#F2867E",
          "danger-soft": "#492D32",
          "on-danger": "#0A0302",
          "info": "#8AB8EA",
          "info-soft": "#333849",
          "avatar-fill": "#252931",
          "data-red": "#D34730",
          "data-orange": "#EA700F",
          "data-yellow": "#E7BD1B",
          "data-green": "#36A462",
          "data-blue": "#159CE2",
          "data-purple": "#8B51E1",
          "data-brown": "#8A6859",
          "data-grey": "#939393",
          "scrim": "#00000099",
          "glass-fill": "#10141CB8",
          "glass-stroke": "#FFFFFF1F",
          "shadow": "#000000"
        }
      }
    },
    {
      "id": "forest",
      "name": "Forest",
      "light": {
        "bg": "#FBF8F4",
        "surface": "#FBF8F4",
        "ink": "#0E1B12",
        "ink-muted": "#4D5D52",
        "accent": "#28603A",
        "on-accent": "#FFFFFF"
      },
      "dark": {
        "bg": "#0F1611",
        "surface": "#0F1611",
        "ink": "#E5EDE8",
        "ink-muted": "#A1AFA5",
        "accent": "#96CAA0",
        "on-accent": "#0D2616"
      },
      "overrides": {
        "light": {
          "surface-raised": "#FFFFFF",
          "surface-sunken": "#ECE8E6",
          "surface-hover": "#DDD9D7",
          "sidebar": "#F5F0EA",
          "line": "#CDD6CF",
          "line-strong": "#868C87",
          "accent-soft": "#E2EDE4",
          "link": "#28603A",
          "selection": "#28603A",
          "on-selection": "#FFFFFF",
          "selection-inactive": "#ECE8E6",
          "focus": "#B3261E",
          "focus-on-danger": "#1C1420",
          "success": "#256B29",
          "success-soft": "#DFE5D8",
          "warning": "#8A5100",
          "warning-soft": "#EDE1D6",
          "danger": "#B3261E",
          "danger-soft": "#F5DED7",
          "on-danger": "#FFFFFF",
          "info": "#1F5FA8",
          "info-soft": "#DEE4EB",
          "avatar-fill": "#DDD9D7",
          "data-red": "#D34730",
          "data-orange": "#EA700F",
          "data-yellow": "#E7BD1B",
          "data-green": "#36A462",
          "data-blue": "#159CE2",
          "data-purple": "#8B51E1",
          "data-brown": "#8A6859",
          "data-grey": "#939393",
          "scrim": "#14141459",
          "glass-fill": "#FBF8F4B8",
          "glass-stroke": "#FFFFFFCC",
          "shadow": "#141414"
        },
        "dark": {
          "surface-raised": "#162019",
          "surface-sunken": "#19201B",
          "surface-hover": "#2D352F",
          "sidebar": "#131B15",
          "line": "#2B382F",
          "line-strong": "#646C66",
          "accent-soft": "#13361D",
          "link": "#96CAA0",
          "selection": "#96CAA0",
          "on-selection": "#0D2616",
          "selection-inactive": "#19201B",
          "focus": "#F2867E",
          "focus-on-danger": "#EFE8F1",
          "success": "#7BC67E",
          "success-soft": "#303B33",
          "warning": "#F0B45A",
          "warning-soft": "#47372D",
          "danger": "#F2867E",
          "danger-soft": "#492D32",
          "on-danger": "#0A0302",
          "info": "#8AB8EA",
          "info-soft": "#333849",
          "avatar-fill": "#242B26",
          "data-red": "#D34730",
          "data-orange": "#EA700F",
          "data-yellow": "#E7BD1B",
          "data-green": "#36A462",
          "data-blue": "#159CE2",
          "data-purple": "#8B51E1",
          "data-brown": "#8A6859",
          "data-grey": "#939393",
          "scrim": "#00000099",
          "glass-fill": "#0F1611B8",
          "glass-stroke": "#FFFFFF1F",
          "shadow": "#000000"
        }
      }
    }
  ],
  "default-palette": "plum",
  "colour-use": {
    "same-as": {
      "toolbar": "bg",
      "edge": "ink"
    }
  },
  "type": {
    "display": [
      "fraunces",
      "serif"
    ],
    "body": [
      "instrument-sans",
      "sans"
    ],
    "mono": [
      "jetbrains-mono",
      "mono"
    ],
    "base": 15,
    "ratio": 1.25,
    "numerals": "proportional",
    "secondary-italic": true,
    "roles": {
      "display-xl": {
        "size": 44,
        "line-height": 1.1,
        "weight": 600,
        "tracking": -0.02
      },
      "display-lg": {
        "size": 34,
        "line-height": 1.12,
        "weight": 600,
        "tracking": -0.015
      },
      "title": {
        "size": 24,
        "line-height": 1.2,
        "weight": 600,
        "tracking": -0.01
      },
      "heading": {
        "size": 16,
        "line-height": 1.4,
        "weight": 600,
        "tracking": 0.01
      },
      "body": {
        "size": 15,
        "line-height": 1.55,
        "weight": 400,
        "tracking": 0
      },
      "body-strong": {
        "size": 15,
        "line-height": 1.55,
        "weight": 600,
        "tracking": 0
      },
      "label": {
        "size": 13,
        "line-height": 1.4,
        "weight": 500,
        "tracking": 0.01
      },
      "caption": {
        "size": 13,
        "line-height": 1.4,
        "weight": 400,
        "tracking": 0
      },
      "mono": {
        "size": 13,
        "line-height": 1.5,
        "weight": 400,
        "tracking": 0
      }
    }
  },
  "shape": {
    "corners": "square",
    "radius": {
      "xs": 2,
      "sm": 2,
      "md": 2,
      "lg": 2,
      "xl": 4
    },
    "controls": "match"
  },
  "density": {
    "desktop": {
      "control": 36,
      "row": 52,
      "icon": 18,
      "space": 1.25
    },
    "phone": {
      "control": 48,
      "row": 60,
      "icon": 22,
      "space": 1.25
    }
  },
  "borders": {
    "width": 1,
    "style": "solid",
    "colour": "edge",
    "cards": false,
    "controls": true,
    "separators": "full",
    "title-rule": "double"
  },
  "elevation": {
    "style": "none",
    "strength": 0,
    "offset": 0,
    "press": "none"
  },
  "materials": {
    "window": {
      "kind": "solid"
    },
    "sidebar": "solid",
    "bars": "solid"
  },
  "icons": {
    "set": "phosphor",
    "weight": "light",
    "selected": "same",
    "tiles": "none"
  },
  "motion": {
    "personality": "calm",
    "scale": 1,
    "press": "dim",
    "enter": "fade"
  },
  "components": {
    "button": {
      "primary": "outline",
      "secondary": "text",
      "plain": "text",
      "shape": "square"
    },
    "list": "ruled",
    "sidebar": "column",
    "toolbar": "flat",
    "inputs": "underlined",
    "selection": "bar",
    "avatar": "none",
    "tabs": "underline",
    "chat": "transcript",
    "month": "open",
    "today": "ring",
    "data-colours": "colour"
  },
  "illustration": "ink",
  "sound": "none"
}
''',
  'mydata.sticker': r'''{
  "format": 1,
  "id": "mydata.sticker",
  "name": "Sticker",
  "version": "1.0.0",
  "author": "myData",
  "licence": "CC0-1.0",
  "description": "Playful and chunky: Fredoka titles, big rounds, 2px ink outlines and sticker shadows that a press squashes.",
  "frame": "drawn",
  "preview": {
    "blurb": "Chunky, round and cheerful.",
    "scene": "calendar"
  },
  "palettes": [
    {
      "id": "rose",
      "name": "Rose",
      "light": {
        "bg": "#FFF4F6",
        "surface": "#FFFFFF",
        "ink": "#2A1520",
        "ink-muted": "#6B4A58",
        "accent": "#A63A5B",
        "on-accent": "#FFFFFF"
      },
      "dark": {
        "bg": "#1C1216",
        "surface": "#2A1C22",
        "ink": "#F7E9EE",
        "ink-muted": "#C9ADB8",
        "accent": "#EFA3B8",
        "on-accent": "#33101C"
      },
      "overrides": {
        "light": {
          "surface-raised": "#FFFFFF",
          "surface-sunken": "#FBE4EA",
          "surface-hover": "#DBD7D9",
          "sidebar": "#FDE8EE",
          "toolbar": "#FFFFFF",
          "line": "#F0D3DC",
          "line-strong": "#9A6577",
          "edge": "#2A1520",
          "accent-soft": "#F8E1E8",
          "link": "#A33858",
          "selection": "#A63A5B",
          "on-selection": "#FFFFFF",
          "selection-inactive": "#F6E1E7",
          "focus": "#2457C5",
          "focus-on-danger": "#2A1520",
          "success": "#256B29",
          "success-soft": "#DDF2DF",
          "warning": "#8A5100",
          "warning-soft": "#FBEBCF",
          "danger": "#B4380E",
          "danger-soft": "#FCE3DA",
          "on-danger": "#FFFFFF",
          "info": "#1F5FA8",
          "info-soft": "#DCE9F8",
          "avatar-fill": "#F9D3DE",
          "data-red": "#D34730",
          "data-orange": "#EA700F",
          "data-yellow": "#E7BD1B",
          "data-green": "#36A462",
          "data-blue": "#159CE2",
          "data-purple": "#8B51E1",
          "data-brown": "#8A6859",
          "data-grey": "#939393",
          "scrim": "#14141459",
          "glass-fill": "#FFFFFFB8",
          "glass-stroke": "#FFFFFFCC",
          "shadow": "#2A1520"
        },
        "dark": {
          "surface-raised": "#33232A",
          "surface-sunken": "#160E11",
          "surface-hover": "#45373D",
          "sidebar": "#22161B",
          "toolbar": "#2A1C22",
          "line": "#43303A",
          "line-strong": "#9E808C",
          "edge": "#E2C4CF",
          "accent-soft": "#4A2632",
          "link": "#F2AEC0",
          "selection": "#EFA3B8",
          "on-selection": "#33101C",
          "selection-inactive": "#36252C",
          "focus": "#8CB4FF",
          "focus-on-danger": "#F7E9EE",
          "success": "#7BC67E",
          "success-soft": "#1E3524",
          "warning": "#F0B45A",
          "warning-soft": "#3D2A12",
          "danger": "#FF9A8A",
          "danger-soft": "#4A1D1E",
          "on-danger": "#2B0B08",
          "info": "#8AB8EA",
          "info-soft": "#1D2D45",
          "avatar-fill": "#4D2B38",
          "data-red": "#D34730",
          "data-orange": "#EA700F",
          "data-yellow": "#E7BD1B",
          "data-green": "#36A462",
          "data-blue": "#159CE2",
          "data-purple": "#8B51E1",
          "data-brown": "#8A6859",
          "data-grey": "#939393",
          "scrim": "#00000099",
          "glass-fill": "#1A1A1AB8",
          "glass-stroke": "#FFFFFF1F",
          "shadow": "#000000"
        }
      },
      "contrast": {
        "light": {
          "ink-muted": "#593846",
          "line-strong": "#976274",
          "line": "#9A6577",
          "link": "#8B2044",
          "accent": "#962C4E",
          "selection": "#9C3153",
          "danger": "#961700",
          "success": "#105A18",
          "warning": "#784000",
          "info": "#024A92"
        },
        "dark": {
          "line": "#9E808C",
          "ink-muted": "#E2C6D1",
          "danger": "#FF9E8D",
          "success": "#83CF86",
          "info": "#8EBDEF"
        }
      }
    },
    {
      "id": "mint",
      "name": "Mint",
      "light": {
        "bg": "#F0FAF6",
        "surface": "#FFFFFF",
        "ink": "#072319",
        "ink-muted": "#395E50",
        "accent": "#057558",
        "on-accent": "#FFFFFF"
      },
      "dark": {
        "bg": "#0D1814",
        "surface": "#15251E",
        "ink": "#E3F1EB",
        "ink-muted": "#A1BEB1",
        "accent": "#7FD9B8",
        "on-accent": "#0A2A20"
      },
      "overrides": {
        "light": {
          "surface-raised": "#FFFFFF",
          "surface-sunken": "#DBF1E7",
          "surface-hover": "#D5D9D8",
          "sidebar": "#E0F4EB",
          "toolbar": "#FFFFFF",
          "line": "#C7E4D7",
          "line-strong": "#49856F",
          "edge": "#072319",
          "accent-soft": "#DDECE5",
          "link": "#057558",
          "selection": "#057558",
          "on-selection": "#FFFFFF",
          "selection-inactive": "#D9EDE4",
          "focus": "#2457C5",
          "focus-on-danger": "#2A1520",
          "success": "#256B29",
          "success-soft": "#DDF2DF",
          "warning": "#8A5100",
          "warning-soft": "#FBEBCF",
          "danger": "#B4380E",
          "danger-soft": "#FCE3DA",
          "on-danger": "#FFFFFF",
          "info": "#1F5FA8",
          "info-soft": "#DCE9F8",
          "avatar-fill": "#C3E9D9",
          "data-red": "#D34730",
          "data-orange": "#EA700F",
          "data-yellow": "#E7BD1B",
          "data-green": "#36A462",
          "data-blue": "#159CE2",
          "data-purple": "#8B51E1",
          "data-brown": "#8A6859",
          "data-grey": "#939393",
          "scrim": "#14141459",
          "glass-fill": "#FFFFFFB8",
          "glass-stroke": "#FFFFFFCC",
          "shadow": "#2A1520"
        },
        "dark": {
          "surface-raised": "#1B2D26",
          "surface-sunken": "#0A130F",
          "surface-hover": "#313F39",
          "sidebar": "#101D18",
          "toolbar": "#15251E",
          "line": "#263C33",
          "line-strong": "#729285",
          "edge": "#B7D6C9",
          "accent-soft": "#073D2D",
          "link": "#7FD9B8",
          "selection": "#7FD9B8",
          "on-selection": "#0A2A20",
          "selection-inactive": "#1D2F28",
          "focus": "#8CB4FF",
          "focus-on-danger": "#F7E9EE",
          "success": "#7BC67E",
          "success-soft": "#1E3524",
          "warning": "#F0B45A",
          "warning-soft": "#3D2A12",
          "danger": "#FF9A8A",
          "danger-soft": "#4A1D1E",
          "on-danger": "#2B0B08",
          "info": "#8AB8EA",
          "info-soft": "#1D2D45",
          "avatar-fill": "#164032",
          "data-red": "#D34730",
          "data-orange": "#EA700F",
          "data-yellow": "#E7BD1B",
          "data-green": "#36A462",
          "data-blue": "#159CE2",
          "data-purple": "#8B51E1",
          "data-brown": "#8A6859",
          "data-grey": "#939393",
          "scrim": "#00000099",
          "glass-fill": "#1A1A1AB8",
          "glass-stroke": "#FFFFFF1F",
          "shadow": "#000000"
        }
      },
      "contrast": {
        "light": {
          "ink-muted": "#22493B",
          "line-strong": "#45826C",
          "line": "#49856F",
          "link": "#00573D",
          "accent": "#006146",
          "selection": "#00664A",
          "danger": "#961700",
          "success": "#105A18",
          "warning": "#784000",
          "info": "#024A92"
        },
        "dark": {
          "line": "#729285",
          "ink-muted": "#BAD7CA",
          "danger": "#FF9E8D",
          "success": "#83CF86",
          "info": "#8EBDEF",
          "link": "#7FD9B8"
        }
      }
    },
    {
      "id": "mustard",
      "name": "Mustard",
      "light": {
        "bg": "#FAF7EE",
        "surface": "#FFFFFF",
        "ink": "#221C06",
        "ink-muted": "#5E5535",
        "accent": "#866700",
        "on-accent": "#FFFFFF"
      },
      "dark": {
        "bg": "#19150C",
        "surface": "#262013",
        "ink": "#F2EDE1",
        "ink-muted": "#C0B59D",
        "accent": "#EFCA55",
        "on-accent": "#2A2005"
      },
      "overrides": {
        "light": {
          "surface-raised": "#FFFFFF",
          "surface-sunken": "#F0EBD8",
          "surface-hover": "#D9D8D5",
          "sidebar": "#F3EFDD",
          "toolbar": "#FFFFFF",
          "line": "#E3DCC3",
          "line-strong": "#847744",
          "edge": "#221C06",
          "accent-soft": "#EEE8D9",
          "link": "#836400",
          "selection": "#866700",
          "on-selection": "#FFFFFF",
          "selection-inactive": "#ECE8D6",
          "focus": "#2457C5",
          "focus-on-danger": "#2A1520",
          "success": "#256B29",
          "success-soft": "#DDF2DF",
          "warning": "#8A5100",
          "warning-soft": "#FBEBCF",
          "danger": "#B4380E",
          "danger-soft": "#FCE3DA",
          "on-danger": "#FFFFFF",
          "info": "#1F5FA8",
          "info-soft": "#DCE9F8",
          "avatar-fill": "#E8DFBE",
          "data-red": "#D34730",
          "data-orange": "#EA700F",
          "data-yellow": "#E7BD1B",
          "data-green": "#36A462",
          "data-blue": "#159CE2",
          "data-purple": "#8B51E1",
          "data-brown": "#8A6859",
          "data-grey": "#939393",
          "scrim": "#14141459",
          "glass-fill": "#FFFFFFB8",
          "glass-stroke": "#FFFFFFCC",
          "shadow": "#2A1520"
        },
        "dark": {
          "surface-raised": "#2F2719",
          "surface-sunken": "#141009",
          "surface-hover": "#413B2F",
          "sidebar": "#1F190E",
          "toolbar": "#262013",
          "line": "#3E3523",
          "line-strong": "#95886E",
          "edge": "#D8CCB3",
          "accent-soft": "#423000",
          "link": "#EFCA55",
          "selection": "#EFCA55",
          "on-selection": "#2A2005",
          "selection-inactive": "#312A1A",
          "focus": "#8CB4FF",
          "focus-on-danger": "#F7E9EE",
          "success": "#7BC67E",
          "success-soft": "#1E3524",
          "warning": "#F0B45A",
          "warning-soft": "#3D2A12",
          "danger": "#FF9A8A",
          "danger-soft": "#4A1D1E",
          "on-danger": "#2B0B08",
          "info": "#8AB8EA",
          "info-soft": "#1D2D45",
          "avatar-fill": "#443513",
          "data-red": "#D34730",
          "data-orange": "#EA700F",
          "data-yellow": "#E7BD1B",
          "data-green": "#36A462",
          "data-blue": "#159CE2",
          "data-purple": "#8B51E1",
          "data-brown": "#8A6859",
          "data-grey": "#939393",
          "scrim": "#00000099",
          "glass-fill": "#1A1A1AB8",
          "glass-stroke": "#FFFFFF1F",
          "shadow": "#000000"
        }
      },
      "contrast": {
        "light": {
          "ink-muted": "#4B4221",
          "line-strong": "#817440",
          "line": "#847744",
          "link": "#644700",
          "accent": "#6D4F00",
          "selection": "#725400",
          "danger": "#961700",
          "success": "#105A18",
          "warning": "#784000",
          "info": "#024A92"
        },
        "dark": {
          "line": "#95886E",
          "ink-muted": "#D9CEB6",
          "danger": "#FF9E8D",
          "success": "#83CF86",
          "info": "#8EBDEF"
        }
      }
    }
  ],
  "default-palette": "rose",
  "type": {
    "display": [
      "fredoka",
      "nunito",
      "sans"
    ],
    "body": [
      "nunito",
      "sans"
    ],
    "mono": [
      "jetbrains-mono",
      "mono"
    ],
    "base": 15,
    "ratio": 1.25,
    "numerals": "proportional",
    "secondary-italic": false,
    "roles": {
      "display-xl": {
        "size": 40,
        "line-height": 1.1,
        "weight": 600,
        "tracking": -0.01
      },
      "display-lg": {
        "size": 30,
        "line-height": 1.15,
        "weight": 600,
        "tracking": -0.01
      },
      "title": {
        "size": 24,
        "line-height": 1.2,
        "weight": 600,
        "tracking": 0
      },
      "heading": {
        "size": 18,
        "line-height": 1.3,
        "weight": 600,
        "tracking": 0,
        "stack": "display"
      },
      "body": {
        "size": 15,
        "line-height": 1.5,
        "weight": 500,
        "tracking": 0
      },
      "body-strong": {
        "size": 15,
        "line-height": 1.5,
        "weight": 800,
        "tracking": 0
      },
      "label": {
        "size": 13,
        "line-height": 1.3,
        "weight": 700,
        "tracking": 0.01
      },
      "caption": {
        "size": 12.5,
        "line-height": 1.4,
        "weight": 500,
        "tracking": 0
      },
      "mono": {
        "size": 13,
        "line-height": 1.4,
        "weight": 400,
        "tracking": 0
      }
    }
  },
  "shape": {
    "corners": "round",
    "radius": {
      "xs": 6,
      "sm": 12,
      "md": 16,
      "lg": 24,
      "xl": 28
    },
    "controls": "pill"
  },
  "density": {
    "desktop": {
      "control": 40,
      "row": 52,
      "icon": 20,
      "space": 1.15
    },
    "phone": {
      "control": 48,
      "row": 60,
      "icon": 22,
      "space": 1.15
    }
  },
  "borders": {
    "width": 2,
    "style": "solid",
    "colour": "edge",
    "cards": true,
    "controls": true,
    "separators": "inset",
    "title-rule": "none"
  },
  "elevation": {
    "style": "hard",
    "strength": 1,
    "offset": 4,
    "press": "collapse"
  },
  "materials": {
    "window": {
      "kind": "solid"
    },
    "sidebar": "solid",
    "bars": "solid"
  },
  "icons": {
    "set": "phosphor",
    "weight": "bold",
    "selected": "fill",
    "tiles": "tinted"
  },
  "motion": {
    "personality": "lively",
    "scale": 1,
    "press": "sink",
    "enter": "fade-rise"
  },
  "components": {
    "button": {
      "primary": "brutal",
      "secondary": "outline",
      "plain": "text",
      "shape": "pill"
    },
    "list": "bordered",
    "sidebar": "source-list",
    "toolbar": "floating",
    "inputs": "outlined",
    "selection": "tint",
    "avatar": "circle",
    "tabs": "pill",
    "chat": "bubbles",
    "month": "boxed",
    "today": "disc",
    "data-colours": "colour"
  },
  "illustration": "flat",
  "sound": "none"
}
''',
  'mydata.paperback': r'''{
  "format": 1,
  "id": "mydata.paperback",
  "name": "Paperback",
  "version": "1.0.0",
  "author": "myData",
  "licence": "CC0-1.0",
  "description": "A reading lamp: paper, a book serif set for long reading, italic secondary text, calm pages and soft shadows.",
  "frame": "drawn",
  "preview": {
    "blurb": "Paper under a reading lamp.",
    "scene": "contacts"
  },
  "palettes": [
    {
      "id": "amber",
      "name": "Amber",
      "light": {
        "bg": "#F4ECDD",
        "surface": "#FBF6EC",
        "ink": "#2B2118",
        "ink-muted": "#63554A",
        "accent": "#8A5100",
        "on-accent": "#FFFFFF"
      },
      "dark": {
        "bg": "#1A1510",
        "surface": "#231C15",
        "ink": "#EDE2D0",
        "ink-muted": "#B5A690",
        "accent": "#F0B45A",
        "on-accent": "#2E1B00"
      },
      "overrides": {
        "light": {
          "surface-raised": "#FFFBF3",
          "surface-sunken": "#E8E0D1",
          "surface-hover": "#D6D0C6",
          "sidebar": "#EFE5D2",
          "line": "#E6DAC4",
          "line-strong": "#87817B",
          "accent-soft": "#F5E3C4",
          "link": "#8A5100",
          "selection": "#8A5100",
          "on-selection": "#FFFFFF",
          "selection-inactive": "#E8E0D1",
          "focus": "#2457C5",
          "focus-on-danger": "#2B2118",
          "success": "#256B29",
          "success-soft": "#DDE3D1",
          "warning": "#755600",
          "warning-soft": "#E8E0CB",
          "danger": "#B3261E",
          "danger-soft": "#F1D9CF",
          "on-danger": "#FFFFFF",
          "info": "#1F5FA8",
          "info-soft": "#DCE1E2",
          "avatar-fill": "#E9DCC3",
          "data-red": "#D34730",
          "data-orange": "#E16C0E",
          "data-yellow": "#E7BD1B",
          "data-green": "#349F5F",
          "data-blue": "#1494D7",
          "data-purple": "#8B51E1",
          "data-brown": "#8A6859",
          "data-grey": "#8D8D8D",
          "scrim": "#14141459",
          "glass-fill": "#FBF6ECB8",
          "glass-stroke": "#FFFFFFCC",
          "shadow": "#5A3A10"
        },
        "dark": {
          "surface-raised": "#2C241B",
          "surface-sunken": "#27211C",
          "surface-hover": "#3F382F",
          "sidebar": "#16120D",
          "line": "#3A3025",
          "line-strong": "#776E63",
          "accent-soft": "#3D2C0C",
          "link": "#F0B45A",
          "selection": "#F0B45A",
          "on-selection": "#2E1B00",
          "selection-inactive": "#27211C",
          "focus": "#8CB4FF",
          "focus-on-danger": "#EDE2D0",
          "success": "#7BC67E",
          "success-soft": "#38452E",
          "warning": "#E2C766",
          "warning-soft": "#514528",
          "danger": "#F38B83",
          "danger-soft": "#55352E",
          "on-danger": "#2C1918",
          "info": "#8AB8EA",
          "info-soft": "#3C4148",
          "avatar-fill": "#3A3025",
          "data-red": "#D34730",
          "data-orange": "#EA700F",
          "data-yellow": "#E7BD1B",
          "data-green": "#36A462",
          "data-blue": "#159CE2",
          "data-purple": "#8B51E1",
          "data-brown": "#8A6859",
          "data-grey": "#939393",
          "scrim": "#00000099",
          "glass-fill": "#231C15B8",
          "glass-stroke": "#FFFFFF1F",
          "shadow": "#000000"
        }
      }
    },
    {
      "id": "sepia",
      "name": "Sepia",
      "light": {
        "bg": "#F2ECE3",
        "surface": "#FAF6F0",
        "ink": "#27231C",
        "ink-muted": "#5D574F",
        "accent": "#5D4432",
        "on-accent": "#FFFFFF"
      },
      "dark": {
        "bg": "#181512",
        "surface": "#211D18",
        "ink": "#EBE2D8",
        "ink-muted": "#B1A69A",
        "accent": "#CDAD95",
        "on-accent": "#2A1A0E"
      },
      "overrides": {
        "light": {
          "surface-raised": "#FEFBF6",
          "surface-sunken": "#E6E0D7",
          "surface-hover": "#D4D0CA",
          "sidebar": "#ECE5DA",
          "line": "#E3DACE",
          "line-strong": "#84827E",
          "accent-soft": "#EFE3DA",
          "link": "#5D4432",
          "selection": "#5D4432",
          "on-selection": "#FFFFFF",
          "selection-inactive": "#E6E0D7",
          "focus": "#2457C5",
          "focus-on-danger": "#2B2118",
          "success": "#256B29",
          "success-soft": "#DDE3D1",
          "warning": "#755600",
          "warning-soft": "#E8E0CB",
          "danger": "#B3261E",
          "danger-soft": "#F1D9CF",
          "on-danger": "#FFFFFF",
          "info": "#1F5FA8",
          "info-soft": "#DCE1E2",
          "avatar-fill": "#E6DCCE",
          "data-red": "#D34730",
          "data-orange": "#E16C0E",
          "data-yellow": "#E7BD1B",
          "data-green": "#349F5F",
          "data-blue": "#1494D7",
          "data-purple": "#8B51E1",
          "data-brown": "#8A6859",
          "data-grey": "#8D8D8D",
          "scrim": "#14141459",
          "glass-fill": "#FAF6F0B8",
          "glass-stroke": "#FFFFFFCC",
          "shadow": "#5A3A10"
        },
        "dark": {
          "surface-raised": "#29251F",
          "surface-sunken": "#25221E",
          "surface-hover": "#3D3833",
          "sidebar": "#15120F",
          "line": "#37312A",
          "line-strong": "#746E68",
          "accent-soft": "#372D25",
          "link": "#CDAD95",
          "selection": "#CDAD95",
          "on-selection": "#2A1A0E",
          "selection-inactive": "#25221E",
          "focus": "#8CB4FF",
          "focus-on-danger": "#EDE2D0",
          "success": "#7BC67E",
          "success-soft": "#38452E",
          "warning": "#E2C766",
          "warning-soft": "#514528",
          "danger": "#F38B83",
          "danger-soft": "#55352E",
          "on-danger": "#2C1918",
          "info": "#8AB8EA",
          "info-soft": "#3C4148",
          "avatar-fill": "#37312A",
          "data-red": "#D34730",
          "data-orange": "#EA700F",
          "data-yellow": "#E7BD1B",
          "data-green": "#36A462",
          "data-blue": "#159CE2",
          "data-purple": "#8B51E1",
          "data-brown": "#8A6859",
          "data-grey": "#939393",
          "scrim": "#00000099",
          "glass-fill": "#211D18B8",
          "glass-stroke": "#FFFFFF1F",
          "shadow": "#000000"
        }
      }
    },
    {
      "id": "linen",
      "name": "Linen",
      "light": {
        "bg": "#E6EEF2",
        "surface": "#F2F8FA",
        "ink": "#1E2427",
        "ink-muted": "#525A5D",
        "accent": "#2B616D",
        "on-accent": "#FFFFFF"
      },
      "dark": {
        "bg": "#121719",
        "surface": "#191F21",
        "ink": "#D9E6EC",
        "ink-muted": "#9BABB2",
        "accent": "#8DC6D0",
        "on-accent": "#0E2228"
      },
      "overrides": {
        "light": {
          "surface-raised": "#F8FCFE",
          "surface-sunken": "#DAE2E6",
          "surface-hover": "#CCD2D4",
          "sidebar": "#DEE8EC",
          "line": "#D2DEE3",
          "line-strong": "#7F8384",
          "accent-soft": "#D4EAF0",
          "link": "#2B616D",
          "selection": "#2B616D",
          "on-selection": "#FFFFFF",
          "selection-inactive": "#DAE2E6",
          "focus": "#B3261E",
          "focus-on-danger": "#2B2118",
          "success": "#256B29",
          "success-soft": "#DDE3D1",
          "warning": "#755600",
          "warning-soft": "#E8E0CB",
          "danger": "#B3261E",
          "danger-soft": "#F1D9CF",
          "on-danger": "#FFFFFF",
          "info": "#1F5FA8",
          "info-soft": "#DCE1E2",
          "avatar-fill": "#D3E0E6",
          "data-red": "#D34730",
          "data-orange": "#E16C0E",
          "data-yellow": "#E7BD1B",
          "data-green": "#349F5F",
          "data-blue": "#1494D7",
          "data-purple": "#8B51E1",
          "data-brown": "#8A6859",
          "data-grey": "#8D8D8D",
          "scrim": "#14141459",
          "glass-fill": "#F2F8FAB8",
          "glass-stroke": "#FFFFFFCC",
          "shadow": "#5A3A10"
        },
        "dark": {
          "surface-raised": "#20272A",
          "surface-sunken": "#1E2325",
          "surface-hover": "#333B3E",
          "sidebar": "#0F1315",
          "line": "#2B3437",
          "line-strong": "#687175",
          "accent-soft": "#203336",
          "link": "#8DC6D0",
          "selection": "#8DC6D0",
          "on-selection": "#0E2228",
          "selection-inactive": "#1E2325",
          "focus": "#F2867E",
          "focus-on-danger": "#EDE2D0",
          "success": "#7BC67E",
          "success-soft": "#38452E",
          "warning": "#E2C766",
          "warning-soft": "#514528",
          "danger": "#F38B83",
          "danger-soft": "#55352E",
          "on-danger": "#2C1918",
          "info": "#8AB8EA",
          "info-soft": "#3C4148",
          "avatar-fill": "#2B3437",
          "data-red": "#D34730",
          "data-orange": "#EA700F",
          "data-yellow": "#E7BD1B",
          "data-green": "#36A462",
          "data-blue": "#159CE2",
          "data-purple": "#8B51E1",
          "data-brown": "#8A6859",
          "data-grey": "#939393",
          "scrim": "#00000099",
          "glass-fill": "#191F21B8",
          "glass-stroke": "#FFFFFF1F",
          "shadow": "#000000"
        }
      }
    }
  ],
  "default-palette": "amber",
  "colour-use": {
    "same-as": {
      "toolbar": "bg",
      "edge": "ink"
    }
  },
  "type": {
    "display": [
      "literata",
      "serif"
    ],
    "body": [
      "literata",
      "serif"
    ],
    "mono": [
      "jetbrains-mono",
      "mono"
    ],
    "base": 16,
    "ratio": 1.2,
    "numerals": "proportional",
    "secondary-italic": true,
    "roles": {
      "display-xl": {
        "size": 40,
        "line-height": 1.15,
        "weight": 600,
        "tracking": -0.01
      },
      "display-lg": {
        "size": 30,
        "line-height": 1.2,
        "weight": 600,
        "tracking": -0.01
      },
      "title": {
        "size": 23,
        "line-height": 1.25,
        "weight": 600
      },
      "heading": {
        "size": 19,
        "line-height": 1.3,
        "weight": 600,
        "stack": "display"
      },
      "body": {
        "size": 16,
        "line-height": 1.55,
        "weight": 400
      },
      "body-strong": {
        "size": 16,
        "line-height": 1.55,
        "weight": 600
      },
      "label": {
        "size": 14,
        "line-height": 1.3,
        "weight": 500
      },
      "caption": {
        "size": 13,
        "line-height": 1.4,
        "weight": 400
      },
      "mono": {
        "size": 14,
        "line-height": 1.5,
        "weight": 400
      }
    }
  },
  "shape": {
    "corners": "round",
    "radius": {
      "xs": 4,
      "sm": 8,
      "md": 10,
      "lg": 12,
      "xl": 16
    },
    "controls": "match"
  },
  "density": {
    "preset": "regular",
    "desktop": {
      "control": 36,
      "row": 48,
      "icon": 18,
      "space": 1.1
    }
  },
  "borders": {
    "width": 1,
    "style": "solid",
    "colour": "line",
    "cards": false,
    "controls": false,
    "separators": "inset",
    "title-rule": "none"
  },
  "elevation": {
    "style": "soft",
    "strength": 0.6,
    "press": "none"
  },
  "materials": {
    "window": {
      "kind": "pattern",
      "pattern": {
        "kind": "grain",
        "opacity": 0.04,
        "colour": "ink"
      }
    },
    "sidebar": "solid",
    "bars": "solid"
  },
  "icons": {
    "set": "lucide",
    "weight": "light",
    "selected": "same",
    "tiles": "tinted"
  },
  "motion": {
    "personality": "calm",
    "scale": 1.15,
    "press": "dim",
    "enter": "fade"
  },
  "components": {
    "button": {
      "primary": "filled",
      "secondary": "tonal",
      "plain": "text",
      "shape": "rounded"
    },
    "list": "inset",
    "sidebar": "column",
    "toolbar": "flat",
    "inputs": "underlined",
    "selection": "tint",
    "avatar": "circle",
    "tabs": "underline",
    "chat": "transcript",
    "month": "open",
    "today": "disc",
    "data-colours": "colour"
  },
  "illustration": "ink",
  "sound": "none"
}
''',
  'mydata.high-contrast': r'''{
  "format": 1,
  "id": "mydata.high-contrast",
  "name": "High Contrast",
  "version": "1.0.0",
  "author": "myData",
  "licence": "CC0-1.0",
  "description": "The most contrast there is: black and white, every word at 7:1 or more, 2 px edges on every control and container, inverse selection, underlined links and a double focus ring.",
  "frame": "drawn",
  "preview": {
    "blurb": "Every edge and word as clear as it can be.",
    "scene": "contacts"
  },
  "palettes": [
    {
      "id": "blue",
      "name": "Blue",
      "light": {
        "bg": "#FFFFFF",
        "surface": "#FFFFFF",
        "ink": "#000000",
        "ink-muted": "#2B2B2B",
        "accent": "#0B3D91",
        "on-accent": "#FFFFFF"
      },
      "dark": {
        "bg": "#000000",
        "surface": "#000000",
        "ink": "#FFFFFF",
        "ink-muted": "#E0E0E0",
        "accent": "#8CB4FF",
        "on-accent": "#000000"
      },
      "overrides": {
        "light": {
          "surface-raised": "#FFFFFF",
          "surface-sunken": "#F0F0F0",
          "surface-hover": "#D6D6D6",
          "sidebar": "#FFFFFF",
          "toolbar": "#FFFFFF",
          "line": "#595959",
          "accent-soft": "#DDE6F6",
          "link": "#0B3D91",
          "selection-inactive": "#D6D6D6",
          "focus": "#B2055B",
          "focus-on-danger": "#000000",
          "success": "#0D5816",
          "success-soft": "#E2EBE2",
          "warning": "#704100",
          "warning-soft": "#F0E7DF",
          "danger": "#9D0104",
          "danger-soft": "#F9E4E1",
          "on-danger": "#FFFFFF",
          "info": "#054C93",
          "info-soft": "#E1EAF5",
          "avatar-fill": "#E6E6E6",
          "data-red": "#D34730",
          "data-orange": "#EA700F",
          "data-yellow": "#B39100",
          "data-green": "#36A462",
          "data-blue": "#159CE2",
          "data-purple": "#8B51E1",
          "data-brown": "#8A6859",
          "data-grey": "#939393",
          "scrim": "#14141459",
          "glass-fill": "#FFFFFFB8",
          "glass-stroke": "#FFFFFFCC",
          "shadow": "#141414"
        },
        "dark": {
          "surface-raised": "#121212",
          "surface-sunken": "#0A0A0A",
          "surface-hover": "#3A3A3A",
          "sidebar": "#000000",
          "toolbar": "#000000",
          "line": "#A0A0A0",
          "accent-soft": "#0E1F3D",
          "link": "#8CB4FF",
          "selection-inactive": "#3A3A3A",
          "focus": "#E865AB",
          "focus-on-danger": "#FFFFFF",
          "success": "#7BC67E",
          "success-soft": "#0B190C",
          "warning": "#F0B45A",
          "warning-soft": "#211606",
          "danger": "#F2867E",
          "danger-soft": "#220D0C",
          "on-danger": "#0A0302",
          "info": "#8AB8EA",
          "info-soft": "#0E1720",
          "avatar-fill": "#262626",
          "data-red": "#D34730",
          "data-orange": "#EA700F",
          "data-yellow": "#E7BD1B",
          "data-green": "#36A462",
          "data-blue": "#159CE2",
          "data-purple": "#8B51E1",
          "data-brown": "#8A6859",
          "data-grey": "#939393",
          "scrim": "#00000099",
          "glass-fill": "#000000B8",
          "glass-stroke": "#FFFFFF1F",
          "shadow": "#000000"
        }
      }
    },
    {
      "id": "yellow",
      "name": "Yellow",
      "light": {
        "bg": "#FFFFFF",
        "surface": "#FFFFFF",
        "ink": "#000000",
        "ink-muted": "#2B2B2B",
        "accent": "#000000",
        "on-accent": "#FFE14D"
      },
      "dark": {
        "bg": "#000000",
        "surface": "#000000",
        "ink": "#FFFFFF",
        "ink-muted": "#E0E0E0",
        "accent": "#FFD60A",
        "on-accent": "#000000"
      },
      "overrides": {
        "light": {
          "surface-raised": "#FFFFFF",
          "surface-sunken": "#F0F0F0",
          "surface-hover": "#D6D6D6",
          "sidebar": "#FFFFFF",
          "toolbar": "#FFFFFF",
          "line": "#595959",
          "accent-soft": "#FFF2A8",
          "link": "#5C4300",
          "selection-inactive": "#D6D6D6",
          "focus": "#B2055B",
          "focus-on-danger": "#000000",
          "success": "#0D5816",
          "success-soft": "#E2EBE2",
          "warning": "#704100",
          "warning-soft": "#F0E7DF",
          "danger": "#9D0104",
          "danger-soft": "#F9E4E1",
          "on-danger": "#FFFFFF",
          "info": "#054C93",
          "info-soft": "#E1EAF5",
          "avatar-fill": "#E6E6E6",
          "data-red": "#D34730",
          "data-orange": "#EA700F",
          "data-yellow": "#B39100",
          "data-green": "#36A462",
          "data-blue": "#159CE2",
          "data-purple": "#8B51E1",
          "data-brown": "#8A6859",
          "data-grey": "#939393",
          "scrim": "#14141459",
          "glass-fill": "#FFFFFFB8",
          "glass-stroke": "#FFFFFFCC",
          "shadow": "#141414"
        },
        "dark": {
          "surface-raised": "#121212",
          "surface-sunken": "#0A0A0A",
          "surface-hover": "#3A3A3A",
          "sidebar": "#000000",
          "toolbar": "#000000",
          "line": "#A0A0A0",
          "accent-soft": "#3A3000",
          "link": "#FFD60A",
          "selection-inactive": "#3A3A3A",
          "focus": "#E865AB",
          "focus-on-danger": "#FFFFFF",
          "success": "#7BC67E",
          "success-soft": "#0B190C",
          "warning": "#F0B45A",
          "warning-soft": "#211606",
          "danger": "#F2867E",
          "danger-soft": "#220D0C",
          "on-danger": "#0A0302",
          "info": "#8AB8EA",
          "info-soft": "#0E1720",
          "avatar-fill": "#262626",
          "data-red": "#D34730",
          "data-orange": "#EA700F",
          "data-yellow": "#E7BD1B",
          "data-green": "#36A462",
          "data-blue": "#159CE2",
          "data-purple": "#8B51E1",
          "data-brown": "#8A6859",
          "data-grey": "#939393",
          "scrim": "#00000099",
          "glass-fill": "#000000B8",
          "glass-stroke": "#FFFFFF1F",
          "shadow": "#000000"
        }
      }
    },
    {
      "id": "cyan",
      "name": "Cyan",
      "light": {
        "bg": "#FFFFFF",
        "surface": "#FFFFFF",
        "ink": "#000000",
        "ink-muted": "#2B2B2B",
        "accent": "#00525C",
        "on-accent": "#FFFFFF"
      },
      "dark": {
        "bg": "#000000",
        "surface": "#000000",
        "ink": "#FFFFFF",
        "ink-muted": "#E0E0E0",
        "accent": "#5CE1E6",
        "on-accent": "#000000"
      },
      "overrides": {
        "light": {
          "surface-raised": "#FFFFFF",
          "surface-sunken": "#F0F0F0",
          "surface-hover": "#D6D6D6",
          "sidebar": "#FFFFFF",
          "toolbar": "#FFFFFF",
          "line": "#595959",
          "accent-soft": "#D6EFF1",
          "link": "#00525C",
          "selection-inactive": "#D6D6D6",
          "focus": "#B2055B",
          "focus-on-danger": "#000000",
          "success": "#0D5816",
          "success-soft": "#E2EBE2",
          "warning": "#704100",
          "warning-soft": "#F0E7DF",
          "danger": "#9D0104",
          "danger-soft": "#F9E4E1",
          "on-danger": "#FFFFFF",
          "info": "#054C93",
          "info-soft": "#E1EAF5",
          "avatar-fill": "#E6E6E6",
          "data-red": "#D34730",
          "data-orange": "#EA700F",
          "data-yellow": "#B39100",
          "data-green": "#36A462",
          "data-blue": "#159CE2",
          "data-purple": "#8B51E1",
          "data-brown": "#8A6859",
          "data-grey": "#939393",
          "scrim": "#14141459",
          "glass-fill": "#FFFFFFB8",
          "glass-stroke": "#FFFFFFCC",
          "shadow": "#141414"
        },
        "dark": {
          "surface-raised": "#121212",
          "surface-sunken": "#0A0A0A",
          "surface-hover": "#3A3A3A",
          "sidebar": "#000000",
          "toolbar": "#000000",
          "line": "#A0A0A0",
          "accent-soft": "#00363A",
          "link": "#5CE1E6",
          "selection-inactive": "#3A3A3A",
          "focus": "#E865AB",
          "focus-on-danger": "#FFFFFF",
          "success": "#7BC67E",
          "success-soft": "#0B190C",
          "warning": "#F0B45A",
          "warning-soft": "#211606",
          "danger": "#F2867E",
          "danger-soft": "#220D0C",
          "on-danger": "#0A0302",
          "info": "#8AB8EA",
          "info-soft": "#0E1720",
          "avatar-fill": "#262626",
          "data-red": "#D34730",
          "data-orange": "#EA700F",
          "data-yellow": "#E7BD1B",
          "data-green": "#36A462",
          "data-blue": "#159CE2",
          "data-purple": "#8B51E1",
          "data-brown": "#8A6859",
          "data-grey": "#939393",
          "scrim": "#00000099",
          "glass-fill": "#000000B8",
          "glass-stroke": "#FFFFFF1F",
          "shadow": "#000000"
        }
      }
    }
  ],
  "default-palette": "blue",
  "colour-use": {
    "same-as": {
      "selection": "ink",
      "on-selection": "bg",
      "edge": "ink",
      "line-strong": "ink"
    }
  },
  "type": {
    "display": [
      "atkinson-hyperlegible-next",
      "sans"
    ],
    "body": [
      "atkinson-hyperlegible-next",
      "sans"
    ],
    "mono": [
      "atkinson-hyperlegible-mono",
      "mono"
    ],
    "base": 16,
    "ratio": 1.2,
    "numerals": "tabular",
    "secondary-italic": false,
    "roles": {
      "display-xl": {
        "size": 40,
        "line-height": 1.15,
        "weight": 800,
        "tracking": -0.01
      },
      "display-lg": {
        "size": 30,
        "line-height": 1.2,
        "weight": 800,
        "tracking": -0.01
      },
      "title": {
        "size": 22,
        "line-height": 1.27,
        "weight": 800,
        "tracking": 0
      },
      "heading": {
        "size": 18,
        "line-height": 1.33,
        "weight": 700,
        "tracking": 0
      },
      "body": {
        "size": 16,
        "line-height": 1.5,
        "weight": 400,
        "tracking": 0.01
      },
      "body-strong": {
        "size": 16,
        "line-height": 1.5,
        "weight": 700,
        "tracking": 0.01
      },
      "label": {
        "size": 15,
        "line-height": 1.4,
        "weight": 700,
        "tracking": 0.01
      },
      "caption": {
        "size": 14,
        "line-height": 1.43,
        "weight": 400,
        "tracking": 0.01
      },
      "mono": {
        "size": 15,
        "line-height": 1.47,
        "weight": 400,
        "tracking": 0
      }
    }
  },
  "shape": {
    "corners": "round",
    "radius": {
      "xs": 4,
      "sm": 8,
      "md": 8,
      "lg": 8,
      "xl": 12
    },
    "controls": "match"
  },
  "density": {
    "desktop": {
      "control": 40,
      "row": 48,
      "icon": 20,
      "space": 1
    },
    "phone": {
      "control": 48,
      "row": 56,
      "icon": 24,
      "space": 1
    }
  },
  "borders": {
    "width": 2,
    "style": "solid",
    "colour": "edge",
    "cards": true,
    "controls": true,
    "separators": "full",
    "title-rule": "single",
    "focus": "double"
  },
  "elevation": {
    "style": "none",
    "strength": 0,
    "press": "none"
  },
  "materials": {
    "window": {
      "kind": "solid"
    },
    "sidebar": "solid",
    "bars": "solid"
  },
  "icons": {
    "set": "material-outlined",
    "weight": "bold",
    "selected": "fill",
    "tiles": "outlined"
  },
  "motion": {
    "personality": "calm",
    "scale": 0.75,
    "press": "dim",
    "enter": "fade"
  },
  "components": {
    "button": {
      "primary": "filled",
      "secondary": "outline",
      "plain": "underline",
      "shape": "rounded"
    },
    "list": "bordered",
    "sidebar": "column",
    "toolbar": "flat",
    "inputs": "outlined",
    "selection": "inverse",
    "avatar": "circle",
    "tabs": "boxed",
    "chat": "blocks",
    "month": "boxed",
    "today": "inverse",
    "data-colours": "colour"
  },
  "illustration": "line",
  "accessibility": {
    "text-contrast": "7:1",
    "faint-text": "readable"
  },
  "sound": "none"
}
''',
  'mydata.e-ink': r'''{
  "format": 1,
  "id": "mydata.e-ink",
  "name": "E-ink",
  "version": "1.0.0",
  "author": "myData",
  "licence": "CC0-1.0",
  "description": "E-paper: ink on paper and nothing else, a reading serif, ruled pages instead of boxes, patterns instead of calendar colours, and nothing that moves. Text at 7:1 or more.",
  "frame": "drawn",
  "preview": {
    "blurb": "Ink on paper, nothing moves.",
    "scene": "calendar"
  },
  "palettes": [
    {
      "id": "white",
      "name": "White",
      "light": {
        "bg": "#FFFFFF",
        "surface": "#FFFFFF",
        "ink": "#000000",
        "ink-muted": "#333333",
        "accent": "#000000",
        "on-accent": "#FFFFFF"
      },
      "dark": {
        "bg": "#000000",
        "surface": "#000000",
        "ink": "#FFFFFF",
        "ink-muted": "#CCCCCC",
        "accent": "#FFFFFF",
        "on-accent": "#000000"
      },
      "overrides": {
        "light": {
          "surface-sunken": "#F0F0F0",
          "surface-hover": "#DADADA",
          "accent-soft": "#E6E6E6",
          "surface-raised": "#FFFFFF",
          "sidebar": "#FFFFFF",
          "toolbar": "#FFFFFF",
          "selection-inactive": "#E6E6E6",
          "focus": "#6A6A6A",
          "data-red": "#D34730",
          "data-orange": "#EA700F",
          "data-yellow": "#E7BD1B",
          "data-green": "#36A462",
          "data-blue": "#159CE2",
          "data-purple": "#8B51E1",
          "data-brown": "#8A6859",
          "data-grey": "#939393",
          "scrim": "#00000080",
          "glass-fill": "#FFFFFF",
          "glass-stroke": "#000000",
          "shadow": "#000000"
        },
        "dark": {
          "surface-raised": "#0A0A0A",
          "surface-sunken": "#141414",
          "surface-hover": "#333333",
          "accent-soft": "#262626",
          "sidebar": "#000000",
          "toolbar": "#000000",
          "selection-inactive": "#262626",
          "focus": "#888888",
          "data-red": "#D34730",
          "data-orange": "#EA700F",
          "data-yellow": "#E7BD1B",
          "data-green": "#36A462",
          "data-blue": "#159CE2",
          "data-purple": "#8B51E1",
          "data-brown": "#8A6859",
          "data-grey": "#939393",
          "scrim": "#000000B3",
          "glass-fill": "#000000",
          "glass-stroke": "#FFFFFF",
          "shadow": "#000000"
        }
      }
    },
    {
      "id": "cream",
      "name": "Cream",
      "light": {
        "bg": "#F6F0E0",
        "surface": "#F6F0E0",
        "ink": "#1C1A16",
        "ink-muted": "#3D3A33",
        "accent": "#1C1A16",
        "on-accent": "#F6F0E0"
      },
      "dark": {
        "bg": "#1B1915",
        "surface": "#1B1915",
        "ink": "#F3EDDE",
        "ink-muted": "#CFC8B7",
        "accent": "#F3EDDE",
        "on-accent": "#1B1915"
      },
      "overrides": {
        "light": {
          "surface-sunken": "#ECE5D2",
          "surface-hover": "#D6CEB8",
          "accent-soft": "#E4DCC6",
          "surface-raised": "#F6F0E0",
          "sidebar": "#F6F0E0",
          "toolbar": "#F6F0E0",
          "selection-inactive": "#E4DCC6",
          "focus": "#6F6C66",
          "data-red": "#D34730",
          "data-orange": "#EA700F",
          "data-yellow": "#E7BD1B",
          "data-green": "#36A462",
          "data-blue": "#159CE2",
          "data-purple": "#8B51E1",
          "data-brown": "#8A6859",
          "data-grey": "#939393",
          "scrim": "#00000080",
          "glass-fill": "#F6F0E0",
          "glass-stroke": "#1C1A16",
          "shadow": "#000000"
        },
        "dark": {
          "surface-raised": "#211F1A",
          "surface-sunken": "#23211C",
          "surface-hover": "#36332C",
          "accent-soft": "#302D26",
          "sidebar": "#1B1915",
          "toolbar": "#1B1915",
          "selection-inactive": "#302D26",
          "focus": "#84827D",
          "data-red": "#D34730",
          "data-orange": "#EA700F",
          "data-yellow": "#E7BD1B",
          "data-green": "#36A462",
          "data-blue": "#159CE2",
          "data-purple": "#8B51E1",
          "data-brown": "#8A6859",
          "data-grey": "#939393",
          "scrim": "#000000B3",
          "glass-fill": "#1B1915",
          "glass-stroke": "#F3EDDE",
          "shadow": "#000000"
        }
      }
    },
    {
      "id": "grey",
      "name": "Grey",
      "light": {
        "bg": "#E4E4E0",
        "surface": "#E4E4E0",
        "ink": "#0F0F0F",
        "ink-muted": "#2E2E2E",
        "accent": "#0F0F0F",
        "on-accent": "#E4E4E0"
      },
      "dark": {
        "bg": "#232323",
        "surface": "#232323",
        "ink": "#ECECEC",
        "ink-muted": "#D2D2D2",
        "accent": "#ECECEC",
        "on-accent": "#232323"
      },
      "overrides": {
        "light": {
          "surface-sunken": "#D9D9D4",
          "surface-hover": "#C2C2BD",
          "accent-soft": "#CFCFCA",
          "surface-raised": "#E4E4E0",
          "sidebar": "#E4E4E0",
          "toolbar": "#E4E4E0",
          "selection-inactive": "#CFCFCA",
          "focus": "#656561",
          "data-red": "#D34730",
          "data-orange": "#EA700F",
          "data-yellow": "#E7BD1B",
          "data-green": "#36A462",
          "data-blue": "#159CE2",
          "data-purple": "#8B51E1",
          "data-brown": "#8A6859",
          "data-grey": "#939393",
          "scrim": "#00000080",
          "glass-fill": "#E4E4E0",
          "glass-stroke": "#0F0F0F",
          "shadow": "#000000"
        },
        "dark": {
          "surface-raised": "#272727",
          "surface-sunken": "#1D1D1D",
          "surface-hover": "#3B3B3B",
          "accent-soft": "#323232",
          "sidebar": "#232323",
          "toolbar": "#232323",
          "selection-inactive": "#323232",
          "focus": "#868686",
          "data-red": "#D34730",
          "data-orange": "#EA700F",
          "data-yellow": "#E7BD1B",
          "data-green": "#36A462",
          "data-blue": "#159CE2",
          "data-purple": "#8B51E1",
          "data-brown": "#8A6859",
          "data-grey": "#939393",
          "scrim": "#000000B3",
          "glass-fill": "#232323",
          "glass-stroke": "#ECECEC",
          "shadow": "#000000"
        }
      }
    }
  ],
  "default-palette": "white",
  "colour-use": {
    "same-as": {
      "selection": "ink",
      "on-selection": "bg",
      "edge": "ink",
      "line-strong": "ink",
      "line": "ink",
      "link": "ink",
      "success": "ink",
      "warning": "ink",
      "danger": "ink",
      "info": "ink",
      "focus-on-danger": "ink",
      "on-danger": "bg",
      "success-soft": "surface-sunken",
      "warning-soft": "surface-sunken",
      "danger-soft": "surface-sunken",
      "info-soft": "surface-sunken",
      "avatar-fill": "accent-soft"
    }
  },
  "type": {
    "display": [
      "literata",
      "serif"
    ],
    "body": [
      "literata",
      "serif"
    ],
    "mono": [
      "jetbrains-mono",
      "mono"
    ],
    "base": 16,
    "ratio": 1.2,
    "numerals": "proportional",
    "secondary-italic": false,
    "roles": {
      "display-xl": {
        "size": 34,
        "line-height": 1.2,
        "weight": 700,
        "tracking": -0.01
      },
      "display-lg": {
        "size": 28,
        "line-height": 1.25,
        "weight": 700,
        "tracking": -0.01
      },
      "title": {
        "size": 22,
        "line-height": 1.3,
        "weight": 700,
        "tracking": 0
      },
      "heading": {
        "size": 18,
        "line-height": 1.35,
        "weight": 700,
        "tracking": 0,
        "stack": "display"
      },
      "body": {
        "size": 16,
        "line-height": 1.55,
        "weight": 400,
        "tracking": 0
      },
      "body-strong": {
        "size": 16,
        "line-height": 1.55,
        "weight": 700,
        "tracking": 0
      },
      "label": {
        "size": 14,
        "line-height": 1.35,
        "weight": 600,
        "tracking": 0
      },
      "caption": {
        "size": 13,
        "line-height": 1.4,
        "weight": 400,
        "tracking": 0
      },
      "mono": {
        "size": 14,
        "line-height": 1.45,
        "weight": 400,
        "tracking": 0
      }
    }
  },
  "shape": {
    "corners": "round",
    "radius": {
      "xs": 2,
      "sm": 4,
      "md": 4,
      "lg": 4,
      "xl": 6
    },
    "controls": "match"
  },
  "density": {
    "desktop": {
      "control": 44,
      "row": 56,
      "icon": 20,
      "space": 1.1
    },
    "phone": {
      "control": 48,
      "row": 60,
      "icon": 22,
      "space": 1.1
    }
  },
  "borders": {
    "width": 1,
    "style": "solid",
    "colour": "edge",
    "cards": false,
    "controls": true,
    "separators": "full",
    "title-rule": "single"
  },
  "elevation": {
    "style": "none",
    "strength": 0,
    "press": "none"
  },
  "materials": {
    "window": {
      "kind": "solid"
    },
    "sidebar": "solid",
    "bars": "solid"
  },
  "icons": {
    "set": "phosphor",
    "weight": "regular",
    "selected": "fill",
    "tiles": "none"
  },
  "motion": {
    "personality": "none",
    "scale": 1,
    "press": "invert",
    "enter": "none"
  },
  "components": {
    "button": {
      "primary": "filled",
      "secondary": "outline",
      "plain": "underline",
      "shape": "rounded"
    },
    "list": "ruled",
    "sidebar": "column",
    "toolbar": "flat",
    "inputs": "outlined",
    "selection": "inverse",
    "avatar": "circle",
    "tabs": "underline",
    "chat": "bubbles",
    "month": "open",
    "today": "inverse",
    "data-colours": "pattern"
  },
  "illustration": "line",
  "accessibility": {
    "text-contrast": "7:1",
    "faint-text": "readable"
  },
  "sound": "none"
}
''',
  'mydata.large': r'''{
  "format": 1,
  "id": "mydata.large",
  "name": "Large",
  "version": "1.0.0",
  "author": "myData",
  "licence": "CC0-1.0",
  "description": "Large and simple: 19 px text, 52 px targets, clear 2 px outlines and a calm blue, for low vision, unsteady hands and anyone who wants fewer, bigger things. The layout stays the same.",
  "frame": "drawn",
  "preview": {
    "blurb": "Bigger text and targets, the same layout.",
    "scene": "contacts"
  },
  "palettes": [
    {
      "id": "blue",
      "name": "Blue",
      "light": {
        "bg": "#FFFDF7",
        "surface": "#FFFFFF",
        "ink": "#151515",
        "ink-muted": "#444444",
        "accent": "#1D5FBF",
        "on-accent": "#FFFFFF"
      },
      "dark": {
        "bg": "#121212",
        "surface": "#1E1E1E",
        "ink": "#F5F5F5",
        "ink-muted": "#CFCFCF",
        "accent": "#8EB8FF",
        "on-accent": "#0B1E3D"
      },
      "overrides": {
        "light": {
          "surface-raised": "#FFFFFF",
          "surface-sunken": "#EFEDE7",
          "surface-hover": "#DFDFDF",
          "sidebar": "#FAF6EC",
          "toolbar": "#FFFDF7",
          "line": "#DDD8CC",
          "line-strong": "#6B6B6B",
          "accent-soft": "#D7EDFF",
          "link": "#1D5FBF",
          "selection-inactive": "#EFEDE7",
          "focus": "#8A5300",
          "focus-on-danger": "#151515",
          "success": "#256B29",
          "success-soft": "#E2EBE2",
          "warning": "#8A5100",
          "warning-soft": "#F0E7DF",
          "danger": "#B3261E",
          "danger-soft": "#F9E4E1",
          "on-danger": "#FFFFFF",
          "info": "#1F5FA8",
          "info-soft": "#E1EAF5",
          "avatar-fill": "#DFDFDF",
          "data-red": "#D34730",
          "data-orange": "#EA700F",
          "data-yellow": "#E7BD1B",
          "data-green": "#36A462",
          "data-blue": "#159CE2",
          "data-purple": "#8B51E1",
          "data-brown": "#8A6859",
          "data-grey": "#939393",
          "scrim": "#14141459",
          "glass-fill": "#FFFFFFB8",
          "glass-stroke": "#FFFFFFCC",
          "shadow": "#141414"
        },
        "dark": {
          "surface-raised": "#282828",
          "surface-sunken": "#1D1D1D",
          "surface-hover": "#3B3B3B",
          "sidebar": "#171717",
          "toolbar": "#121212",
          "line": "#3A3A3A",
          "line-strong": "#8A8A8A",
          "accent-soft": "#203250",
          "link": "#8EB8FF",
          "selection-inactive": "#1D1D1D",
          "focus": "#F2B544",
          "focus-on-danger": "#F5F5F5",
          "success": "#7BC67E",
          "success-soft": "#354535",
          "warning": "#F0B45A",
          "warning-soft": "#4E4130",
          "danger": "#F68A82",
          "danger-soft": "#4F3835",
          "on-danger": "#0A0302",
          "info": "#8AB8EA",
          "info-soft": "#38424D",
          "avatar-fill": "#343434",
          "data-red": "#D34730",
          "data-orange": "#EA700F",
          "data-yellow": "#E7BD1B",
          "data-green": "#36A462",
          "data-blue": "#159CE2",
          "data-purple": "#8B51E1",
          "data-brown": "#8A6859",
          "data-grey": "#939393",
          "scrim": "#00000099",
          "glass-fill": "#1E1E1EB8",
          "glass-stroke": "#FFFFFF1F",
          "shadow": "#000000"
        }
      }
    },
    {
      "id": "green",
      "name": "Green",
      "light": {
        "bg": "#FFFDF7",
        "surface": "#FFFFFF",
        "ink": "#151515",
        "ink-muted": "#444444",
        "accent": "#2B6A2E",
        "on-accent": "#FFFFFF"
      },
      "dark": {
        "bg": "#121212",
        "surface": "#1E1E1E",
        "ink": "#F5F5F5",
        "ink-muted": "#CFCFCF",
        "accent": "#8FD392",
        "on-accent": "#0B2410"
      },
      "overrides": {
        "light": {
          "surface-raised": "#FFFFFF",
          "surface-sunken": "#EFEDE7",
          "surface-hover": "#DFDFDF",
          "sidebar": "#FAF6EC",
          "toolbar": "#FFFDF7",
          "line": "#DDD8CC",
          "line-strong": "#6B6B6B",
          "accent-soft": "#D8F5D7",
          "link": "#2B6A2E",
          "selection-inactive": "#EFEDE7",
          "focus": "#8A5300",
          "focus-on-danger": "#151515",
          "success": "#256B29",
          "success-soft": "#E2EBE2",
          "warning": "#8A5100",
          "warning-soft": "#F0E7DF",
          "danger": "#B3261E",
          "danger-soft": "#F9E4E1",
          "on-danger": "#FFFFFF",
          "info": "#1F5FA8",
          "info-soft": "#E1EAF5",
          "avatar-fill": "#DFDFDF",
          "data-red": "#D34730",
          "data-orange": "#EA700F",
          "data-yellow": "#E7BD1B",
          "data-green": "#36A462",
          "data-blue": "#159CE2",
          "data-purple": "#8B51E1",
          "data-brown": "#8A6859",
          "data-grey": "#939393",
          "scrim": "#14141459",
          "glass-fill": "#FFFFFFB8",
          "glass-stroke": "#FFFFFFCC",
          "shadow": "#141414"
        },
        "dark": {
          "surface-raised": "#282828",
          "surface-sunken": "#1D1D1D",
          "surface-hover": "#3B3B3B",
          "sidebar": "#171717",
          "toolbar": "#121212",
          "line": "#3A3A3A",
          "line-strong": "#8A8A8A",
          "accent-soft": "#1C3A1E",
          "link": "#8FD392",
          "selection-inactive": "#1D1D1D",
          "focus": "#F2B544",
          "focus-on-danger": "#F5F5F5",
          "success": "#7BC67E",
          "success-soft": "#354535",
          "warning": "#F0B45A",
          "warning-soft": "#4E4130",
          "danger": "#F68A82",
          "danger-soft": "#4F3835",
          "on-danger": "#0A0302",
          "info": "#8AB8EA",
          "info-soft": "#38424D",
          "avatar-fill": "#343434",
          "data-red": "#D34730",
          "data-orange": "#EA700F",
          "data-yellow": "#E7BD1B",
          "data-green": "#36A462",
          "data-blue": "#159CE2",
          "data-purple": "#8B51E1",
          "data-brown": "#8A6859",
          "data-grey": "#939393",
          "scrim": "#00000099",
          "glass-fill": "#1E1E1EB8",
          "glass-stroke": "#FFFFFF1F",
          "shadow": "#000000"
        }
      }
    },
    {
      "id": "purple",
      "name": "Purple",
      "light": {
        "bg": "#FFFDF7",
        "surface": "#FFFFFF",
        "ink": "#151515",
        "ink-muted": "#444444",
        "accent": "#6A3FB5",
        "on-accent": "#FFFFFF"
      },
      "dark": {
        "bg": "#121212",
        "surface": "#1E1E1E",
        "ink": "#F5F5F5",
        "ink-muted": "#CFCFCF",
        "accent": "#D6A3FF",
        "on-accent": "#24123F"
      },
      "overrides": {
        "light": {
          "surface-raised": "#FFFFFF",
          "surface-sunken": "#EFEDE7",
          "surface-hover": "#DFDFDF",
          "sidebar": "#FAF6EC",
          "toolbar": "#FFFDF7",
          "line": "#DDD8CC",
          "line-strong": "#6B6B6B",
          "accent-soft": "#EDE5FF",
          "link": "#6A3FB5",
          "selection-inactive": "#EFEDE7",
          "focus": "#8A5300",
          "focus-on-danger": "#151515",
          "success": "#256B29",
          "success-soft": "#E2EBE2",
          "warning": "#8A5100",
          "warning-soft": "#F0E7DF",
          "danger": "#B3261E",
          "danger-soft": "#F9E4E1",
          "on-danger": "#FFFFFF",
          "info": "#1F5FA8",
          "info-soft": "#E1EAF5",
          "avatar-fill": "#DFDFDF",
          "data-red": "#D34730",
          "data-orange": "#EA700F",
          "data-yellow": "#E7BD1B",
          "data-green": "#36A462",
          "data-blue": "#159CE2",
          "data-purple": "#8B51E1",
          "data-brown": "#8A6859",
          "data-grey": "#939393",
          "scrim": "#14141459",
          "glass-fill": "#FFFFFFB8",
          "glass-stroke": "#FFFFFFCC",
          "shadow": "#141414"
        },
        "dark": {
          "surface-raised": "#282828",
          "surface-sunken": "#1D1D1D",
          "surface-hover": "#3B3B3B",
          "sidebar": "#171717",
          "toolbar": "#121212",
          "line": "#3A3A3A",
          "line-strong": "#8A8A8A",
          "accent-soft": "#3B2949",
          "link": "#D6A3FF",
          "selection-inactive": "#1D1D1D",
          "focus": "#F2B544",
          "focus-on-danger": "#F5F5F5",
          "success": "#7BC67E",
          "success-soft": "#354535",
          "warning": "#F0B45A",
          "warning-soft": "#4E4130",
          "danger": "#F68A82",
          "danger-soft": "#4F3835",
          "on-danger": "#0A0302",
          "info": "#8AB8EA",
          "info-soft": "#38424D",
          "avatar-fill": "#343434",
          "data-red": "#D34730",
          "data-orange": "#EA700F",
          "data-yellow": "#E7BD1B",
          "data-green": "#36A462",
          "data-blue": "#159CE2",
          "data-purple": "#8B51E1",
          "data-brown": "#8A6859",
          "data-grey": "#939393",
          "scrim": "#00000099",
          "glass-fill": "#1E1E1EB8",
          "glass-stroke": "#FFFFFF1F",
          "shadow": "#000000"
        }
      }
    }
  ],
  "default-palette": "blue",
  "colour-use": {
    "same-as": {
      "selection": "accent",
      "on-selection": "on-accent",
      "edge": "line-strong"
    }
  },
  "type": {
    "display": [
      "atkinson-hyperlegible-next",
      "sans"
    ],
    "body": [
      "atkinson-hyperlegible-next",
      "sans"
    ],
    "mono": [
      "jetbrains-mono",
      "mono"
    ],
    "base": 19,
    "ratio": 1.2,
    "numerals": "proportional",
    "secondary-italic": false,
    "roles": {
      "display-xl": {
        "size": 36,
        "line-height": 1.15,
        "weight": 700,
        "tracking": -0.01
      },
      "display-lg": {
        "size": 28,
        "line-height": 1.2,
        "weight": 700,
        "tracking": -0.01
      },
      "title": {
        "size": 24,
        "line-height": 1.25,
        "weight": 700,
        "tracking": 0
      },
      "heading": {
        "size": 21,
        "line-height": 1.33,
        "weight": 700,
        "tracking": 0
      },
      "body": {
        "size": 19,
        "line-height": 1.5,
        "weight": 400,
        "tracking": 0.005
      },
      "body-strong": {
        "size": 19,
        "line-height": 1.5,
        "weight": 700,
        "tracking": 0.005
      },
      "label": {
        "size": 17,
        "line-height": 1.4,
        "weight": 700,
        "tracking": 0.005
      },
      "caption": {
        "size": 16,
        "line-height": 1.4,
        "weight": 400,
        "tracking": 0.005
      },
      "mono": {
        "size": 17,
        "line-height": 1.45,
        "weight": 400,
        "tracking": 0
      }
    }
  },
  "shape": {
    "corners": "round",
    "radius": {
      "xs": 6,
      "sm": 12,
      "md": 14,
      "lg": 18,
      "xl": 24
    },
    "controls": "match"
  },
  "density": {
    "desktop": {
      "control": 52,
      "row": 58,
      "icon": 24,
      "space": 1.25
    },
    "phone": {
      "control": 56,
      "row": 64,
      "icon": 24,
      "space": 1.25
    }
  },
  "borders": {
    "width": 2,
    "style": "solid",
    "colour": "line-strong",
    "cards": true,
    "controls": true,
    "separators": "full",
    "title-rule": "none"
  },
  "elevation": {
    "style": "soft",
    "strength": 0.25,
    "press": "none"
  },
  "materials": {
    "window": {
      "kind": "solid"
    },
    "sidebar": "solid",
    "bars": "solid"
  },
  "icons": {
    "set": "material-rounded",
    "weight": "regular",
    "selected": "fill",
    "tiles": "tinted"
  },
  "motion": {
    "personality": "calm",
    "scale": 1,
    "press": "dim",
    "enter": "fade"
  },
  "components": {
    "button": {
      "primary": "filled",
      "secondary": "outline",
      "plain": "underline",
      "shape": "rounded"
    },
    "list": "bordered",
    "sidebar": "column",
    "toolbar": "flat",
    "inputs": "outlined",
    "selection": "outline",
    "avatar": "circle",
    "tabs": "boxed",
    "chat": "bubbles",
    "month": "boxed",
    "today": "disc",
    "data-colours": "colour"
  },
  "illustration": "flat",
  "accessibility": {
    "text-contrast": "4.5:1",
    "faint-text": "readable"
  },
  "sound": "none"
}
''',
};

/// The soft elevation at strength 0.5, from tokens.json "shadow": y offset, CSS blur and alpha in
/// light and dark, for the resting, raised and floating levels.
const softElevationLevels = [
  (y: 4, cssBlur: 20, alphaLight: 18, alphaDark: 89), // shadow-1
  (y: 12, cssBlur: 36, alphaLight: 36, alphaDark: 153), // shadow-2
  (y: 10, cssBlur: 32, alphaLight: 36, alphaDark: 153), // shadow-glass
];
