(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`ChatbookStylesheetBuilder`" ];

ClearAll[ "`*" ];
ClearAll[ "`Private`*" ];

$ChatbookStylesheet;
BuildChatbookStylesheet;

System`LinkedItems;
System`MenuAnchor;
System`MenuItem;
System`RawInputForm;
System`ToggleMenuItem;
System`Scope;

Begin[ "`Private`" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Config*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Paths*)
$assetLocation      = FileNameJoin @ { DirectoryName @ $InputFileName, "Resources" };
$iconDirectory      = FileNameJoin @ { $assetLocation, "Icons" };
$ninePatchDirectory = FileNameJoin @ { $assetLocation, "NinePatchImages" };
$styleDataFile      = FileNameJoin @ { $assetLocation, "Styles.wl" };
$styleSheetTarget   = FileNameJoin @ { DirectoryName[ $InputFileName, 2 ], "FrontEnd", "StyleSheets", "Chatbook.nb" };

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Resources*)

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*$floatingButtonNinePatch*)
$floatingButtonNinePatch = Import @ FileNameJoin @ { $ninePatchDirectory, "FloatingButtonGrid.wxf" };

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*$suppressButtonAppearance*)
$suppressButtonAppearance = Dynamic @ FEPrivate`FrontEndResource[
    "FEExpressions",
    "SuppressMouseDownNinePatchAppearance"
];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*$icons*)
$icons := $icons = Association @ Map[
    FileBaseName @ # -> Import @ # &,
    FileNames[ All, $iconDirectory ]
];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*$askMenuItem*)
$askMenuItem = MenuItem[
    "Ask AI Assistant",
    KernelExecute[
        With[
            { $CellContext`nbo = InputNotebook[ ] },
            { $CellContext`cells = SelectedCells @ $CellContext`nbo },
            Quiet @ Needs[ "Wolfram`Chatbook`" -> None ];
            Symbol[ "Wolfram`Chatbook`ChatbookAction" ][ "Ask", $CellContext`nbo, $CellContext`cells ]
        ]
    ],
    MenuEvaluator -> Automatic,
    Method        -> "Queued"
];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*$excludeMenuItem*)
$excludeMenuItem = MenuItem[
    "Include/Exclude From AI Chat",
    KernelExecute[
        With[
            { $CellContext`nbo = InputNotebook[ ] },
            { $CellContext`cells = SelectedCells @ $CellContext`nbo },
            Quiet @ Needs[ "Wolfram`Chatbook`" -> None ];
            Symbol[ "Wolfram`Chatbook`ChatbookAction" ][ "ExclusionToggle", $CellContext`nbo, $CellContext`cells ]
        ]
    ],
    MenuEvaluator -> Automatic,
    Method        -> "Queued"
];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*contextMenu*)
contextMenu[ a___, name_String, b___ ] := contextMenu[ a, FrontEndResource[ "ContextMenus", name ], b ];
contextMenu[ a___, list_List, b___ ] := contextMenu @@ Flatten @ { a, list, b };
contextMenu[ a___ ] := Flatten @ { a };

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*menuInitializer*)
menuInitializer[ name_String, color_ ] :=
    With[ { attach = Cell[ BoxData @ TemplateBox[ { name, color }, "ChatMenuButton" ], "ChatMenu" ] },
        Initialization :> With[ { $CellContext`cell = EvaluationCell[ ] },
            NotebookDelete @ Cells[ $CellContext`cell, AttachedCell -> True, CellStyle -> "ChatMenu" ];
            AttachCell[
                $CellContext`cell,
                attach,
                { Right, Top },
                Offset[ { -7, -7 }, { Right, Top } ],
                { Right, Top },
                RemovalConditions -> { "EvaluatorQuit" }
            ]
        ]
    ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*$chatOutputMenu*)
$chatOutputMenu := $chatOutputMenu = ToBoxes @ makeMenu[
    {
        (* Icon              , Label                      , ActionName          *)
        { "IconizeIcon"      , "Regenerate"               , "Regenerate"         },
        Delimiter,
        { "DivideCellsIcon"  , "Explode Cells (In Place)" , "ExplodeInPlace"     },
        { "OverflowIcon"     , "Explode Cells (Duplicate)", "ExplodeDuplicate"   },
        { "HyperlinkCopyIcon", "Copy Exploded Cells"      , "CopyExplodedCells"  },
        Delimiter,
        { "TypesettingIcon"  , "Toggle Formatting"        , "ToggleFormatting"   },
        { "InPlaceIcon"      , "Copy ChatObject"          , "CopyChatObject"     },
        { "GroupCellsIcon"   , "Lock Response"            , "LockResponse"       },
        { "AbortAllIcon"     , "Disable AI Assistant"     , "DisableAIAssistant" }
    },
    GrayLevel[ 0.85 ],
    250
];


makeMenu[ items_, frameColor_, width_ ] :=
    Pane[
        RawBoxes @ TemplateBox[
            {
                ToBoxes @ Column[ menuItem /@ items, ItemSize -> { Full, 0 }, Spacings -> 0, Alignment -> Left ],
                FrameMargins   -> 3,
                Background     -> GrayLevel[ 1 ],
                RoundingRadius -> 3,
                FrameStyle     -> Directive[ AbsoluteThickness[ 1 ], frameColor ],
                ImageMargins   -> 0
            },
            "Highlighted"
        ],
        ImageSize -> { width, Automatic }
    ];


menuItem[ { args__ } ] := menuItem @ args;

menuItem[ Delimiter ] := RawBoxes @ TemplateBox[ { }, "ChatMenuItemDelimiter" ];

menuItem[ name_String, label_, code_ ] :=
    With[ { icon = $icons[ name ] },
        If[ MissingQ @ icon,
            menuItem[ RawBoxes @ TemplateBox[ { name }, "ChatMenuItemToolbarIcon" ], label, code ],
            menuItem[ icon, label, code ]
        ]
    ];

menuItem[ icon_, label_, action_String ] :=
    menuItem[
        icon,
        label,
        Hold @ With[
            { $CellContext`cell = EvaluationCell[ ] },
            { $CellContext`root = ParentCell @ $CellContext`cell },
            NotebookDelete @ $CellContext`cell;
            Quiet @ Needs[ "Wolfram`Chatbook`" -> None ];
            Symbol[ "Wolfram`Chatbook`ChatbookAction" ][ action, $CellContext`root ]
        ]
    ];

menuItem[ icon_, label_, None ] :=
    menuItem[ icon, label, Hold[ NotebookDelete @ EvaluationCell[ ]; MessageDialog[ "Not Implemented" ] ] ];

menuItem[ icon_, label_, code_ ] :=
    RawBoxes @ TemplateBox[ { ToBoxes @ icon, ToBoxes @ label, code }, "ChatMenuItem" ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*inlineResources*)
inlineResources[ expr_ ] := expr /. {
    HoldPattern[ $icons[ name_String ] ]    :> RuleCondition @ $icons @ name,
    HoldPattern @ $askMenuItem              :> RuleCondition @ $askMenuItem,
    HoldPattern @ $defaultChatbookSettings  :> RuleCondition @ $defaultChatbookSettings,
    HoldPattern @ $suppressButtonAppearance :> RuleCondition @ $suppressButtonAppearance
};

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*$styleDataCells*)
$styleDataCells := $styleDataCells = inlineResources @ Cases[ ReadList @ $styleDataFile, _Cell ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Default Settings*)
$defaultChatbookSettings := (
    Needs[ "Wolfram`Chatbook`" -> None ];
    KeyMap[ ToString, Association @ Options @ Wolfram`Chatbook`CreateChatNotebook ]
);

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*$ChatbookStylesheet*)
$ChatbookStylesheet = Notebook[
    Flatten @ {
        Cell @ StyleData[ StyleDefinitions -> "Default.nb" ],
        $styleDataCells
    },
    StyleDefinitions -> "PrivateStylesheetFormatting.nb"
];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*BuildChatbookStylesheet*)
BuildChatbookStylesheet[ ] := BuildChatbookStylesheet @ $styleSheetTarget;

BuildChatbookStylesheet[ target_ ] :=
    Module[ { exported },
        exported = Export[ target, $ChatbookStylesheet, "NB" ];
        PacletInstall[ "Wolfram/PacletCICD" ];
        Needs[ "Wolfram`PacletCICD`" -> None ];
        Wolfram`PacletCICD`FormatNotebooks @ exported;
        exported
    ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
End[ ];
EndPackage[ ];