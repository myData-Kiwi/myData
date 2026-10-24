// GENERATED from design/themes/theme.schema.json, design/themes/system/theme.json, design/tokens.json
// and design/themes.json by tool/generate_tokens.dart. Do not edit: change the JSON and run
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

/// The System theme (design/themes/system/theme.json).
const systemThemeJson = r'''{
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
''';

/// Kiwi as the apps draw it today, in today's six colours (tool/themes_codegen.dart).
const kiwiThemeJson = r'''{
  "format": 1,
  "id": "mydata.kiwi",
  "name": "Kiwi",
  "version": "0.1.0",
  "author": "myData",
  "licence": "CC0-1.0",
  "description": "Kiwi as the apps draw it today, in today's six colours: generated from design/tokens.json and design/themes.json. Phase 3 replaces it with design/themes/kiwi.",
  "frame": "drawn",
  "preview": {
    "blurb": "Soft and airy, with glass bars.",
    "scene": "contacts"
  },
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
    "base": 15.0,
    "ratio": 1.2,
    "numerals": "proportional",
    "secondary-italic": false,
    "roles": {
      "display-xl": {
        "size": 40.0,
        "line-height": 1.15,
        "weight": 700,
        "tracking": -0.02,
        "stack": "display"
      },
      "display-lg": {
        "size": 30.0,
        "line-height": 1.2,
        "weight": 700,
        "tracking": -0.02,
        "stack": "display"
      },
      "title": {
        "size": 22.0,
        "line-height": 1.2727,
        "weight": 700,
        "tracking": -0.01,
        "stack": "display"
      },
      "heading": {
        "size": 17.0,
        "line-height": 1.4118,
        "weight": 600,
        "stack": "body"
      },
      "body": {
        "size": 15.0,
        "line-height": 1.4667,
        "weight": 400,
        "stack": "body"
      },
      "body-strong": {
        "size": 15.0,
        "line-height": 1.4667,
        "weight": 600,
        "stack": "body"
      },
      "caption": {
        "size": 13.0,
        "line-height": 1.3846,
        "weight": 400,
        "stack": "body"
      },
      "label": {
        "size": 13.0,
        "line-height": 1.3846,
        "weight": 600,
        "stack": "body"
      },
      "mono": {
        "size": 13.0,
        "line-height": 1.5385,
        "weight": 400,
        "stack": "mono"
      }
    }
  },
  "shape": {
    "corners": "round",
    "radius": {
      "xs": 6.0,
      "sm": 10.0,
      "md": 14.0,
      "lg": 20.0,
      "xl": 28.0
    },
    "controls": "pill"
  },
  "density": {
    "desktop": {
      "control": 44.0,
      "row": 56.0,
      "icon": 20.0,
      "space": 1
    },
    "phone": {
      "control": 44.0,
      "row": 56.0,
      "icon": 20.0,
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
    "blur": 24.0
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
  "sound": "none",
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
      "id": "graphite",
      "name": "Graphite",
      "light": {
        "bg": "#F6F6F5",
        "surface": "#FFFFFF",
        "ink": "#1A1A19",
        "ink-muted": "#5C5C58",
        "accent": "#232323",
        "on-accent": "#FFFFFF"
      },
      "dark": {
        "bg": "#111111",
        "surface": "#1A1A1A",
        "ink": "#EDEDEB",
        "ink-muted": "#A8A8A4",
        "accent": "#E6E6E4",
        "on-accent": "#161616"
      },
      "overrides": {
        "light": {
          "surface-raised": "#FFFFFF",
          "surface-sunken": "#EDEDEB",
          "surface-hover": "#D9D9D6",
          "line": "#E3E3E0",
          "line-strong": "#83837E",
          "edge": "#1A1A19",
          "accent-soft": "#E7E7E4",
          "link": "#232323",
          "selection": "#232323",
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
          "accent-soft": "#2C2C2C",
          "link": "#E6E6E4",
          "selection": "#E6E6E4",
          "on-selection": "#161616",
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
      "id": "dusk",
      "name": "Dusk",
      "light": {
        "bg": "#F6F6F5",
        "surface": "#FFFFFF",
        "ink": "#1A1A19",
        "ink-muted": "#5C5C58",
        "accent": "#3D5AA9",
        "on-accent": "#FFFFFF"
      },
      "dark": {
        "bg": "#111111",
        "surface": "#1A1A1A",
        "ink": "#EDEDEB",
        "ink-muted": "#A8A8A4",
        "accent": "#9DB4F2",
        "on-accent": "#0E1A3A"
      },
      "overrides": {
        "light": {
          "surface-raised": "#FFFFFF",
          "surface-sunken": "#EDEDEB",
          "surface-hover": "#D9D9D6",
          "line": "#E3E3E0",
          "line-strong": "#83837E",
          "edge": "#1A1A19",
          "accent-soft": "#E5EAF8",
          "link": "#3D5AA9",
          "selection": "#3D5AA9",
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
          "accent-soft": "#232C47",
          "link": "#9DB4F2",
          "selection": "#9DB4F2",
          "on-selection": "#0E1A3A",
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
      "id": "plum",
      "name": "Plum",
      "light": {
        "bg": "#F6F6F5",
        "surface": "#FFFFFF",
        "ink": "#1A1A19",
        "ink-muted": "#5C5C58",
        "accent": "#7A3E8E",
        "on-accent": "#FFFFFF"
      },
      "dark": {
        "bg": "#111111",
        "surface": "#1A1A1A",
        "ink": "#EDEDEB",
        "ink-muted": "#A8A8A4",
        "accent": "#D2A6E0",
        "on-accent": "#2A0F33"
      },
      "overrides": {
        "light": {
          "surface-raised": "#FFFFFF",
          "surface-sunken": "#EDEDEB",
          "surface-hover": "#D9D9D6",
          "line": "#E3E3E0",
          "line-strong": "#83837E",
          "edge": "#1A1A19",
          "accent-soft": "#F1E4F5",
          "link": "#7A3E8E",
          "selection": "#7A3E8E",
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
          "accent-soft": "#3B2145",
          "link": "#D2A6E0",
          "selection": "#D2A6E0",
          "on-selection": "#2A0F33",
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
      "id": "rose",
      "name": "Rose",
      "light": {
        "bg": "#F6F6F5",
        "surface": "#FFFFFF",
        "ink": "#1A1A19",
        "ink-muted": "#5C5C58",
        "accent": "#A63A5B",
        "on-accent": "#FFFFFF"
      },
      "dark": {
        "bg": "#111111",
        "surface": "#1A1A1A",
        "ink": "#EDEDEB",
        "ink-muted": "#A8A8A4",
        "accent": "#EFA3B8",
        "on-accent": "#33101C"
      },
      "overrides": {
        "light": {
          "surface-raised": "#FFFFFF",
          "surface-sunken": "#EDEDEB",
          "surface-hover": "#D9D9D6",
          "line": "#E3E3E0",
          "line-strong": "#83837E",
          "edge": "#1A1A19",
          "accent-soft": "#F8E3E9",
          "link": "#A63A5B",
          "selection": "#A63A5B",
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
          "accent-soft": "#40222B",
          "link": "#EFA3B8",
          "selection": "#EFA3B8",
          "on-selection": "#33101C",
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
      "id": "amber",
      "name": "Amber",
      "light": {
        "bg": "#F6F6F5",
        "surface": "#FFFFFF",
        "ink": "#1A1A19",
        "ink-muted": "#5C5C58",
        "accent": "#8A5100",
        "on-accent": "#FFFFFF"
      },
      "dark": {
        "bg": "#111111",
        "surface": "#1A1A1A",
        "ink": "#EDEDEB",
        "ink-muted": "#A8A8A4",
        "accent": "#F0B45A",
        "on-accent": "#2E1B00"
      },
      "overrides": {
        "light": {
          "surface-raised": "#FFFFFF",
          "surface-sunken": "#EDEDEB",
          "surface-hover": "#D9D9D6",
          "line": "#E3E3E0",
          "line-strong": "#83837E",
          "edge": "#1A1A19",
          "accent-soft": "#FBEBCF",
          "link": "#8A5100",
          "selection": "#8A5100",
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
          "accent-soft": "#3D2C0C",
          "link": "#F0B45A",
          "selection": "#F0B45A",
          "on-selection": "#2E1B00",
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
  ]
}
''';

/// The theme files of design/themes, bundled as assets (the phase 3 looks), by id.
const designedThemeAssets = {
  'mydata.frosted': 'packages/mydata_ui/assets/themes/frosted.json',
  'mydata.hairline': 'packages/mydata_ui/assets/themes/hairline.json',
  'mydata.journal': 'packages/mydata_ui/assets/themes/journal.json',
  'mydata.kiwi': 'packages/mydata_ui/assets/themes/kiwi.json',
  'mydata.paperback': 'packages/mydata_ui/assets/themes/paperback.json',
  'mydata.sticker': 'packages/mydata_ui/assets/themes/sticker.json',
  'mydata.system': 'packages/mydata_ui/assets/themes/system.json',
};

/// The soft elevation at strength 0.5, from tokens.json "shadow": y offset, CSS blur and alpha in
/// light and dark, for the resting, raised and floating levels.
const softElevationLevels = [
  (y: 4, cssBlur: 20, alphaLight: 18, alphaDark: 89), // shadow-1
  (y: 12, cssBlur: 36, alphaLight: 36, alphaDark: 153), // shadow-2
  (y: 10, cssBlur: 32, alphaLight: 36, alphaDark: 153), // shadow-glass
];
