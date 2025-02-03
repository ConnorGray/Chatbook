(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`Tools`" ];
Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"        ];
Needs[ "Wolfram`Chatbook`Common`" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Configuration*)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Definitions*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*$fullExamples*)
$fullExamples :=
    With[ { keys = $fullExamplesKeys },
        If[ keys === { } || $ChatHandlerData[ "ChatNotebookSettings", "ToolMethod" ] === "Service",
            "",
            needsBasePrompt[ "EndTurnToolCall" ];
            StringJoin[
                "## Full examples\n\n",
                "The following are brief conversation examples that demonstrate how you can use tools in a ",
                "conversation with the user.\n\n---\n\n",
                StringRiffle[ Values @ KeyTake[ $fullExamples0, $fullExamplesKeys ], "\n\n---\n\n" ],
                "\n\n---\n"
            ]
        ]
    ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*$fullExamplesKeys*)
$fullExamplesKeys :=
    With[ { selected = Keys @ $selectedTools },
        Select[
            {
                "NaturalLanguageInput"
            },
            ContainsAll[ selected, $exampleDependencies[ #1 ] ] &
        ]
    ];

$exampleDependencies = <|
    "AstroGraphicsDocumentation" -> { "DocumentationLookup" },
    "FileSystemTree"             -> { "DocumentationSearcher", "DocumentationLookup" },
    "FractionalDerivatives"      -> { "DocumentationSearcher", "DocumentationLookup", "WolframLanguageEvaluator" },
    "NaturalLanguageInput"       -> { "WolframLanguageEvaluator" },
    "PlotEvaluate"               -> { "WolframLanguageEvaluator" },
    "TemporaryDirectory"         -> { "DocumentationSearcher", "WolframLanguageEvaluator" }
|>;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*$fullExamples0*)
$fullExamples0 = <| |>;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*Example Templates*)
$chatMessageTemplates = <| |>;
$messageTemplateType  = "Basic";

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*Basic*)
$chatMessageTemplates[ "Basic" ] = <| |>;
$chatMessageTemplates[ "Basic", "User"      ] = "User: %%1%%";
$chatMessageTemplates[ "Basic", "Assistant" ] = "Assistant: %%1%%\n/end";
$chatMessageTemplates[ "Basic", "System"    ] = "System: %%1%%";

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*Instruct*)
$chatMessageTemplates[ "Instruct" ] = <| |>;
$chatMessageTemplates[ "Instruct", "User"      ] = "[INST]%%1%%[/INST]";
$chatMessageTemplates[ "Instruct", "Assistant" ] = "%%1%%\n/end";
$chatMessageTemplates[ "Instruct", "System"    ] = "[INST]%%1%%[/INST]";

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*Zephyr*)
$chatMessageTemplates[ "Zephyr" ] = <| |>;
$chatMessageTemplates[ "Zephyr", "User"      ] = "<|user|>\n%%1%%</s>";
$chatMessageTemplates[ "Zephyr", "Assistant" ] = "<|assistant|>\n%%1%%\n/end";
$chatMessageTemplates[ "Zephyr", "System"    ] = "<|system|>\n%%1%%</s>";

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*Phi*)
$chatMessageTemplates[ "Phi" ] = <| |>;
$chatMessageTemplates[ "Phi", "User"      ] = "<|user|>\n%%1%%<|end|>";
$chatMessageTemplates[ "Phi", "Assistant" ] = "<|assistant|>\n%%1%%\n/end<|end|>";
$chatMessageTemplates[ "Phi", "System"    ] = "<|user|>\n%%1%%<|end|>";

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*Boxed*)
$chatMessageTemplates[ "Boxed" ] = <| |>;
$chatMessageTemplates[ "Boxed", "User"      ] = "[user]\n%%1%%";
$chatMessageTemplates[ "Boxed", "Assistant" ] = "[assistant]\n%%1%%\n/end";
$chatMessageTemplates[ "Boxed", "System"    ] = "[system]\n%%1%%";

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*ChatML*)
$chatMessageTemplates[ "ChatML" ] = <| |>;
$chatMessageTemplates[ "ChatML", "User"      ] = "<|im_start|>user\n%%1%%<|im_end|>";
$chatMessageTemplates[ "ChatML", "Assistant" ] = "<|im_start|>assistant\n%%1%%\n/end<|im_end|>";
$chatMessageTemplates[ "ChatML", "System"    ] = "<|im_start|>system\n%%1%%<|im_end|>";

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*XML*)
$chatMessageTemplates[ "XML" ] = <| |>;
$chatMessageTemplates[ "XML", "User"      ] = "<user>%%1%%</user>";
$chatMessageTemplates[ "XML", "Assistant" ] = "<assistant>%%1%%\n/end</assistant>";
$chatMessageTemplates[ "XML", "System"    ] = "<system>%%1%%</system>";

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*DeepSeekCoder*)
$chatMessageTemplates[ "DeepSeekCoder" ] = <| |>;
$chatMessageTemplates[ "DeepSeekCoder", "User"      ] = "User: %%1%%";
$chatMessageTemplates[ "DeepSeekCoder", "Assistant" ] = "Assistant: %%1%%\n/end<\:ff5cend\:2581of\:2581sentence\:ff5c>";
$chatMessageTemplates[ "DeepSeekCoder", "System"    ] = "System: %%1%%";

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*Llama*)
$chatMessageTemplates[ "Llama" ] = <| |>;
$chatMessageTemplates[ "Llama", "User"      ] = "<|start_header_id|>user<|end_header_id|>\n%%1%%<|eot_id|>";
$chatMessageTemplates[ "Llama", "Assistant" ] = "<|start_header_id|>assistant<|end_header_id|>\n%%1%%\n/end<|eot_id|>";
$chatMessageTemplates[ "Llama", "System"    ] = "<|start_header_id|>system<|end_header_id|>\n%%1%%<|eot_id|>";

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*Gemma*)
$chatMessageTemplates[ "Gemma" ] = <| |>;
$chatMessageTemplates[ "Gemma", "User"      ] = "<start_of_turn>user\n%%1%%<end_of_turn>";
$chatMessageTemplates[ "Gemma", "Assistant" ] = "<start_of_turn>model\n%%1%%\n/end<end_of_turn>";
$chatMessageTemplates[ "Gemma", "System"    ] = "<start_of_turn>user\n%%1%%<end_of_turn>";

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*Nemotron*)
$chatMessageTemplates[ "Nemotron" ] = <| |>;
$chatMessageTemplates[ "Nemotron", "User"      ] = "<extra_id_1>User\n%%1%%";
$chatMessageTemplates[ "Nemotron", "Assistant" ] = "<extra_id_1>Assistant\n%%1%%\n/end";
$chatMessageTemplates[ "Nemotron", "System"    ] = "<extra_id_0>System\n%%1%%";

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*messageTemplate*)
messageTemplate // beginDefinition;

messageTemplate[ id_String ] := Enclose[
    StringTemplate[
        ConfirmBy[ $chatMessageTemplates[ $messageTemplateType, id ], StringQ, "TemplateString" ],
        Delimiters -> "%%"
    ],
    throwInternalFailure
];

messageTemplate // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*user*)
user // beginDefinition;
user[ a_List ] := TemplateApply[ messageTemplate[ "User" ], StringRiffle[ TextString /@ Flatten @ a, "\n" ] ];
user[ a_String ] := user @ { a };
user // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*assistant*)
assistant // beginDefinition;
assistant[ { a___, "tool"|"Tool" -> { name_, as_ }, b___ } ] := assistant @ { a, toolCall[ name, as ], b };
assistant[ a_List ] := TemplateApply[ messageTemplate[ "Assistant" ], StringRiffle[ TextString /@ Flatten @ a, "\n" ] ];
assistant[ a_String ] := assistant @ { a };
assistant // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*system*)
system // beginDefinition;
system[ a_List ] := TemplateApply[ messageTemplate[ "System" ], StringRiffle[ TextString /@ Flatten @ a, "\n" ] ];
system[ a_String ] := system @ { a };
system // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*toolCall*)
toolCall // beginDefinition;
toolCall[ args__ ] := formatToolCallExample @ args;
toolCall // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*toolExample*)
toolExample // beginDefinition;
toolExample[ { rules: (_Rule|_String)... } ] := StringRiffle[ toolExample0 /@ { rules }, "\n\n" ];
toolExample[ rules: (_Rule|_String)... ] := toolExample @ { rules };
toolExample // endDefinition;

toolExample0 // beginDefinition;
toolExample0[ "user"|"User"           -> message_ ] := user      @ message;
toolExample0[ "assistant"|"Assistant" -> message_ ] := assistant @ message;
toolExample0[ "system"|"System"       -> message_ ] := system    @ message;
toolExample0[ prompt_String                       ] := prompt;
toolExample0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Full Example Specifications*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*AstroGraphicsDocumentation*)
$fullExamples0[ "AstroGraphicsDocumentation" ] := toolExample[
    "user" -> "How do I use AstroGraphics?",
    "assistant" -> {
        "Let me check the documentation for you. One moment...",
        "tool" -> { "DocumentationLookup", <| "names" -> "AstroGraphics" |> }
    },
    "system" -> {
        "Usage",
        "AstroGraphics[primitives, options] represents a two-dimensional view of space and the celestial sphere.",
        "",
        "Basic Examples",
        "..."
    },
    "assistant" -> "To use [AstroGraphics](paclet:ref/AstroGraphics), you need to..."
];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*NaturalLanguageInput*)
$fullExamples0[ "NaturalLanguageInput" ] := toolExample[
    "user" -> "How far away is NYC from Boston?",
    "assistant" -> {
        "tool" -> {
            "WolframLanguageEvaluator",
            <| "code" -> "GeoDistance[\[FreeformPrompt][\"Boston, MA\"], \[FreeformPrompt][\"New York City\"]]" |>
        }
    },
    "system" -> "Quantity[164.41, \"Miles\"]",
    "assistant" -> "It's 164.41 miles from Boston to New York City.",
    "user" -> "If I made the trip in 3h 17m, how fast was I going?",
    "assistant" -> {
        "tool" -> {
            "WolframLanguageEvaluator",
            <| "code" -> "\[FreeformPrompt][\"164.41 Miles\"] / \[FreeformPrompt][\"3h 17m\"]" |>
        }
    },
    "system" -> "Quantity[50.071, \"Miles\" / \"Hours\"]",
    "assistant" -> "You were going 50.071 miles per hour.",
    "user" -> "What time would I arrive if I left right now?",
    "assistant" -> {
        "tool" -> {
            "WolframLanguageEvaluator",
            <| "code" -> "\[FreeformPrompt][\"3h 17m from now\"]" |>
        }
    }
];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*FileSystemTree*)
$fullExamples0[ "FileSystemTree" ] := toolExample[
    "user" -> "What's the best way to generate a tree of files in a given directory?",
    "assistant" -> {
        "tool" -> { "DocumentationSearcher", <| "query" -> "tree of files" |> }
    },
    "system" -> {
        "* FileSystemTree - (score: 9.9) FileSystemTree[root] gives a tree whose keys are ...",
        "* Tree Drawing - (score: 3.0) ..."
    },
    "assistant" -> {
        "tool" -> { "DocumentationLookup", <| "names" -> "FileSystemTree" |> }
    },
    "..."
];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*FractionalDerivatives*)
$fullExamples0[ "FractionalDerivatives" ] := toolExample[
    "user" -> "Calculate the half-order fractional derivative of x^n with respect to x.",
    "assistant" -> {
        "tool" -> { "DocumentationSearcher", <| "query" -> "fractional derivatives" |> }
    },
    "system" -> {
        "* FractionalD - (score: 9.5) FractionalD[f, {x, a}] gives ...",
        "* NFractionalD - (score: 9.2) ..."
    },
    "assistant" -> {
        "tool" -> { "DocumentationLookup", <| "names" -> "FractionalD" |> }
    },
    "system" -> {
        "Usage",
        "FractionalD[f, {x, a}] gives the Riemann-Liouville fractional derivative D_x^a f(x) of order a of the function f.",
        "",
        "Basic Examples",
        "..."
    },
    "assistant" -> {
        "tool" -> {
            "WolframLanguageEvaluator",
            <| "code" -> "FractionalD[x^n, {x, 1/2}]" |>
        }
    },
    "system" -> {
        "Out[n]= Piecewise[...]\n",
        "![Formatted Result](expression://content-{id})"
    },
    "assistant" -> {
        "The half-order fractional derivative of $$x^n$$ with respect to $$x$$ is given by:",
        "![Fractional Derivative](expression://content-{id})"
    }
];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*PlotEvaluate*)
$fullExamples0[ "PlotEvaluate" ] := toolExample[
    "user" -> "Plot sin(x) from -5 to 5",
    "assistant" -> {
        "tool" -> {
            "WolframLanguageEvaluator",
            <| "code" -> "Plot[Sin[x], {x, -5, 5}, AxesLabel -> {\"x\", \"sin(x)\"}" |>
        }
    },
    "system" -> "Out[n]= ![image](attachment://content-{id})",
    "assistant" -> {
        "Here's the plot of $$\\sin{x}$$ from -5 to 5:",
        "![Plot](attachment://content-{id})"
    }
];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*TemporaryDirectory*)
$fullExamples0[ "TemporaryDirectory" ] := toolExample[
    "user" -> "Where is the temporary directory located?",
    "assistant" -> {
        "tool" -> { "DocumentationSearcher", <| "query" -> "location of temporary directory" |> }
    },
    "system" -> {
        "* $TemporaryDirectory - (score: 9.6) $TemporaryDirectory gives the main system directory for temporary files.",
        "* CreateDirectory - (score: 8.5) CreateDirectory[\"dir\"] creates ..."
    },
    "assistant" -> {
        "tool" -> { "WolframLanguageEvaluator", <| "code" -> "$TemporaryDirectory" |> }
    },
    "system" -> "Out[n]= \"C:\\Users\\UserName\\AppData\\Local\\Temp\"",
    "assistant" -> "The temporary directory is located at C:\\Users\\UserName\\AppData\\Local\\Temp."
];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
addToMXInitialization[
    Null
];

End[ ];
EndPackage[ ];
