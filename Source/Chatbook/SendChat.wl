(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`SendChat`" ];

(* :!CodeAnalysis::BeginBlock:: *)

`$debugLog;
`makeOutputDingbat;
`sendChat;
`toolsEnabledQ;
`writeReformattedCell;

Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"                  ];
Needs[ "Wolfram`Chatbook`Actions`"          ];
Needs[ "Wolfram`Chatbook`ChatGroups`"       ];
Needs[ "Wolfram`Chatbook`ChatMessages`"     ];
Needs[ "Wolfram`Chatbook`Common`"           ];
Needs[ "Wolfram`Chatbook`Formatting`"       ];
Needs[ "Wolfram`Chatbook`FrontEnd`"         ];
Needs[ "Wolfram`Chatbook`InlineReferences`" ];
Needs[ "Wolfram`Chatbook`Models`"           ];
Needs[ "Wolfram`Chatbook`Personas`"         ];
Needs[ "Wolfram`Chatbook`Services`"         ];
Needs[ "Wolfram`Chatbook`Tools`"            ];
Needs[ "Wolfram`Chatbook`Utils`"            ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Configuration*)
$resizeDingbats            = True;
splitDynamicTaskFunction   = createFETask;
$defaultHandlerKeys        = { "BodyChunk", "StatusCode", "Task", "TaskStatus", "EventName" };
$chatSubmitDroppedHandlers = { "ChatPost", "ChatPre" };

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Severity Tag String Patterns*)
$$whitespace  = Longest[ WhitespaceCharacter... ];
$$severityTag = "ERROR"|"WARNING"|"INFO";
$$tagPrefix   = StartOfString~~$$whitespace~~"["~~$$whitespace~~$$severityTag~~$$whitespace~~"]"~~$$whitespace;
$maxTagLength = Max[ StringLength /@ (List @@ $$severityTag) ] + 2;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Initialization*)
$dynamicTrigger    = 0;
$lastDynamicUpdate = 0;
$buffer            = "";

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*SendChat*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*sendChat*)
sendChat // beginDefinition;

sendChat[ evalCell_, nbo_, settings0_ ] /; $useLLMServices := catchTopAs[ ChatbookAction ] @ Enclose[
    Module[ { cells0, cells, target, settings, id, key, messages, data, persona, cell, cellObject, container, task },

        initFETaskWidget @ nbo;

        resolveInlineReferences @ evalCell;
        cells0 = ConfirmMatch[ selectChatCells[ settings0, evalCell, nbo ], { __CellObject }, "SelectChatCells" ];

        { cells, target } = ConfirmMatch[
            chatHistoryCellsAndTarget @ cells0,
            { { __CellObject }, _CellObject | None },
            "HistoryAndTarget"
        ];

        settings = ConfirmBy[
            resolveTools @ resolveAutoSettings @ inheritSettings[ settings0, cells, evalCell ],
            AssociationQ,
            "InheritSettings"
        ];

        If[ TrueQ @ settings[ "EnableChatGroupSettings" ],
            AppendTo[ settings, "ChatGroupSettings" -> getChatGroupSettings @ evalCell ]
        ];

        id  = Lookup[ settings, "ID" ];
        key = toAPIKey[ Automatic, id ];

        If[ ! settings[ "IncludeHistory" ], cells = { evalCell } ];

        If[ ! StringQ @ key, throwFailure[ "NoAPIKey" ] ];

        settings[ "OpenAIKey" ] = key;

        { messages, data } = Reap[
            ConfirmMatch[
                constructMessages[ settings, cells ],
                { __Association },
                "MakeHTTPRequest"
            ],
            $chatDataTag
        ];

        data = ConfirmBy[ Association @ Flatten @ data, AssociationQ, "Data" ];

        If[ data[ "RawOutput" ],
            persona = ConfirmBy[ GetCachedPersonaData[ "RawModel" ], AssociationQ, "NonePersona" ];
            If[ AssociationQ @ settings[ "LLMEvaluator" ],
                settings[ "LLMEvaluator" ] = Association[ settings[ "LLMEvaluator" ], persona ],
                settings = Association[ settings, persona ]
            ]
        ];

        AppendTo[ settings, "Data" -> data ];

        container = <|
            "DynamicContent" -> ProgressIndicator[ Appearance -> "Percolate" ],
            "FullContent"    -> ProgressIndicator[ Appearance -> "Percolate" ],
            "UUID"           -> CreateUUID[ ]
        |>;

        $reformattedCell = None;
        cell = activeAIAssistantCell[
            container,
            Association[ settings, "Container" :> container, "CellObject" :> cellObject, "Task" :> task ]
        ];

        Quiet[
            TaskRemove @ $lastTask;
            NotebookDelete @ $lastCellObject;
        ];

        $resultCellCache = <| |>;
        $debugLog = Internal`Bag[ ];

        If[ ! TrueQ @ $cloudNotebooks && chatInputCellQ @ evalCell,
            SetOptions[
                evalCell,
                CellDingbat -> Cell[ BoxData @ TemplateBox[ { }, "ChatInputCellDingbat" ], Background -> None ]
            ]
        ];

        cellObject = $lastCellObject = ConfirmMatch[
            createNewChatOutput[ settings, target, cell ],
            _CellObject,
            "CreateOutput"
        ];

        getHandlerFunction[ settings, "ChatPre" ][ <|
            "EvaluationCell"       -> evalCell,
            "Messages"             -> messages,
            "CellObject"           -> cellObject,
            "Container"            :> container,
            "ChatNotebookSettings" -> KeyDrop[ settings, { "Data", "OpenAIKey" } ]
        |> ];

        task = ConfirmMatch[
            $lastTask = chatSubmit[ container, messages, cellObject, settings ],
            _TaskObject|_Failure,
            "ChatSubmit"
        ];

        CurrentValue[ cellObject, { TaggingRules, "ChatNotebookSettings", "CellObject" } ] = cellObject;
        CurrentValue[ cellObject, { TaggingRules, "ChatNotebookSettings", "Task"       } ] = task;

        If[ FailureQ @ task, throwTop @ writeErrorCell[ cellObject, task ] ];
        task
    ],
    throwInternalFailure[ sendChat[ evalCell, nbo, settings0 ], ## ] &
];


(* TODO: this definition is obsolete once LLMServices is widely available: *)
sendChat[ evalCell_, nbo_, settings0_ ] := catchTopAs[ ChatbookAction ] @ Enclose[
    Module[ { cells0, cells, target, settings, id, key, messages, req, data, persona, cell, cellObject, container, task },

        initFETaskWidget @ nbo;

        resolveInlineReferences @ evalCell;
        cells0 = ConfirmMatch[ selectChatCells[ settings0, evalCell, nbo ], { __CellObject }, "SelectChatCells" ];

        { cells, target } = ConfirmMatch[
            chatHistoryCellsAndTarget @ cells0,
            { { __CellObject }, _CellObject | None },
            "HistoryAndTarget"
        ];

        settings = ConfirmBy[
            resolveTools @ resolveAutoSettings @ inheritSettings[ settings0, cells, evalCell ],
            AssociationQ,
            "InheritSettings"
        ];

        If[ TrueQ @ settings[ "EnableChatGroupSettings" ],
            AppendTo[ settings, "ChatGroupSettings" -> getChatGroupSettings @ evalCell ]
        ];

        id  = Lookup[ settings, "ID" ];
        key = toAPIKey[ Automatic, id ];

        If[ ! settings[ "IncludeHistory" ], cells = { evalCell } ];

        If[ ! StringQ @ key, throwFailure[ "NoAPIKey" ] ];

        settings[ "OpenAIKey" ] = key;

        { req, data } = Reap[
            ConfirmMatch[
                makeHTTPRequest[ settings, messages = constructMessages[ settings, cells ] ],
                _HTTPRequest,
                "MakeHTTPRequest"
            ],
            $chatDataTag
        ];

        data = ConfirmBy[ Association @ Flatten @ data, AssociationQ, "Data" ];

        If[ data[ "RawOutput" ],
            persona = ConfirmBy[ GetCachedPersonaData[ "RawModel" ], AssociationQ, "NonePersona" ];
            If[ AssociationQ @ settings[ "LLMEvaluator" ],
                settings[ "LLMEvaluator" ] = Association[ settings[ "LLMEvaluator" ], persona ],
                settings = Association[ settings, persona ]
            ]
        ];

        AppendTo[ settings, "Data" -> data ];

        container = <|
            "DynamicContent" -> ProgressIndicator[ Appearance -> "Percolate" ],
            "FullContent"    -> ProgressIndicator[ Appearance -> "Percolate" ],
            "UUID"           -> CreateUUID[ ]
        |>;

        $reformattedCell = None;
        cell = activeAIAssistantCell[
            container,
            Association[ settings, "Container" :> container, "CellObject" :> cellObject, "Task" :> task ]
        ];

        Quiet[
            TaskRemove @ $lastTask;
            NotebookDelete @ $lastCellObject;
        ];

        $resultCellCache = <| |>;
        $debugLog = Internal`Bag[ ];

        If[ ! TrueQ @ $cloudNotebooks && chatInputCellQ @ evalCell,
            SetOptions[
                evalCell,
                CellDingbat -> Cell[ BoxData @ TemplateBox[ { }, "ChatInputCellDingbat" ], Background -> None ]
            ]
        ];

        cellObject = $lastCellObject = ConfirmMatch[
            createNewChatOutput[ settings, target, cell ],
            _CellObject,
            "CreateOutput"
        ];

        getHandlerFunction[ settings, "ChatPre" ][ <|
            "EvaluationCell"       -> evalCell,
            "Messages"             -> messages,
            "CellObject"           -> cellObject,
            "Container"            :> container,
            "ChatNotebookSettings" -> KeyDrop[ settings, { "Data", "OpenAIKey" } ]
        |> ];

        task = Confirm[ $lastTask = chatSubmit[ container, req, cellObject, settings ] ];

        CurrentValue[ cellObject, { TaggingRules, "ChatNotebookSettings", "CellObject" } ] = cellObject;
        CurrentValue[ cellObject, { TaggingRules, "ChatNotebookSettings", "Task"       } ] = task;
    ],
    throwInternalFailure[ sendChat[ evalCell, nbo, settings0 ], ## ] &
];

sendChat // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*getHandlerFunctions*)
getHandlerFunctions // beginDefinition;
getHandlerFunctions[ settings_Association ] := getHandlerFunctions[ settings, Lookup[ settings, "HandlerFunctions" ] ];
getHandlerFunctions[ _, handlers_Association ] := <| $DefaultChatHandlerFunctions, replaceCellContext @ handlers |>;
getHandlerFunctions[ _, $$unspecified ] := $DefaultChatHandlerFunctions;
getHandlerFunctions[ _, handlers_ ] := (messagePrint[ "InvalidHandlers", handlers ]; $DefaultChatHandlerFunctions);
getHandlerFunctions // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*getHandlerFunction*)
getHandlerFunction // beginDefinition;

getHandlerFunction[ settings_Association, name_String ] :=
    getHandlerFunction[ settings, name, getHandlerFunctions @ settings ];

getHandlerFunction[ settings_, name_String, handlers_Association ] :=
    Replace[ Lookup[ handlers, name ],
             $$unspecified :> Lookup[ $DefaultChatHandlerFunctions, name, None ]
    ];

getHandlerFunction // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*makeHTTPRequest*)
makeHTTPRequest // beginDefinition;

(* cSpell: ignore ENDTOOLCALL *)
makeHTTPRequest[ settings_Association? AssociationQ, messages: { __Association } ] :=
    Enclose @ Module[ { key, stream, model, tokens, temperature, topP, freqPenalty, presPenalty, data, body },

        key         = ConfirmBy[ Lookup[ settings, "OpenAIKey" ], StringQ ];
        stream      = True;

        (* model parameters *)
        model       = Lookup[ settings, "Model"           , "gpt-3.5-turbo" ];
        tokens      = Lookup[ settings, "MaxTokens"       , Automatic       ];
        temperature = Lookup[ settings, "Temperature"     , 0.7             ];
        topP        = Lookup[ settings, "TopP"            , 1               ];
        freqPenalty = Lookup[ settings, "FrequencyPenalty", 0.1             ];
        presPenalty = Lookup[ settings, "PresencePenalty" , 0.1             ];

        data = DeleteCases[
            <|
                "messages"          -> prepareMessagesForHTTPRequest @ messages,
                "temperature"       -> temperature,
                "max_tokens"        -> tokens,
                "top_p"             -> topP,
                "frequency_penalty" -> freqPenalty,
                "presence_penalty"  -> presPenalty,
                "model"             -> toModelName @ model,
                "stream"            -> stream,
                "stop"              -> "ENDTOOLCALL"
            |>,
            Automatic|_Missing
        ];

        body = ConfirmBy[ Developer`WriteRawJSONString[ data, "Compact" -> True ], StringQ ];

        $lastRequest = HTTPRequest[
            "https://api.openai.com/v1/chat/completions",
            <|
                "Headers" -> <|
                    "Content-Type"  -> "application/json",
                    "Authorization" -> "Bearer "<>key
                |>,
                "Body"   -> body,
                "Method" -> "POST"
            |>
        ]
    ];

makeHTTPRequest // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*prepareMessagesForHTTPRequest*)
prepareMessagesForHTTPRequest // beginDefinition;
prepareMessagesForHTTPRequest[ message_Association ] := prepareMessagesForHTTPRequest0 @ KeyMap[ ToLowerCase, message ];
prepareMessagesForHTTPRequest[ messages_List ] := prepareMessagesForHTTPRequest /@ messages;
prepareMessagesForHTTPRequest // endDefinition;

prepareMessagesForHTTPRequest0 // beginDefinition;

prepareMessagesForHTTPRequest0[ message: KeyValuePattern[ "role" -> role_String ] ] :=
    Insert[ message, "role" -> ToLowerCase @ role, Key[ "role" ] ];

prepareMessagesForHTTPRequest0[ message_Association ] :=
    message;

prepareMessagesForHTTPRequest0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*chatSubmit*)
chatSubmit // beginDefinition;
chatSubmit // Attributes = { HoldFirst };

chatSubmit[ args__ ] := Quiet[
    chatSubmit0 @ args,
    {
        (* cSpell: ignore wname, invm *)
        ServiceConnections`SavedConnections::wname,
        ServiceConnections`ServiceConnections::wname,
        URLSubmit::invm
    }
];

chatSubmit // endDefinition;

(* TODO: chatHandlers could probably filter valid keys instead of quieting URLSubmit::invm, but the list of available
         events is defined via a private symbol that might not be safe to use:
         URLUtilities`Submit`PackagePrivate`$eventNames
*)

chatSubmit0 // beginDefinition;
chatSubmit0 // Attributes = { HoldFirst };

chatSubmit0[ container_, messages: { __Association }, cellObject_, settings_ ] := (
    Needs[ "LLMServices`" -> None ];
    $lastChatSubmit = LLMServices`ChatSubmit[
        standardizeMessageKeys @ messages,
        makeLLMConfiguration @ settings,
        HandlerFunctions     -> chatHandlers[ container, cellObject, settings ],
        HandlerFunctionsKeys -> chatHandlerFunctionsKeys @ settings
    ]
);

(* TODO: this definition is obsolete once LLMServices is widely available: *)
chatSubmit0[ container_, req_HTTPRequest, cellObject_, settings_ ] := (
    $buffer = "";
    URLSubmit[
        req,
        HandlerFunctions     -> chatHandlers[ container, cellObject, settings ],
        HandlerFunctionsKeys -> chatHandlerFunctionsKeys @ settings,
        CharacterEncoding    -> "UTF8"
    ]
);

chatSubmit0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*makeLLMConfiguration*)
makeLLMConfiguration // beginDefinition;

makeLLMConfiguration[ as: KeyValuePattern[ "Model" -> model_String ] ] :=
    makeLLMConfiguration @ Append[ as, "Model" -> { "OpenAI", model } ];

(* FIXME: get valid claude keys using the following patterns:
ServiceConnectionUtilities`ConnectionInformation["Anthropic", "ProcessedRequests", "Chat", "Parameters"]
*)

makeLLMConfiguration[ as_Association ] :=
    $lastLLMConfiguration = LLMConfiguration @ Association[
        KeyTake[ as, { "Model" } ],
        "StopTokens" -> { "ENDTOOLCALL" }
    ];

makeLLMConfiguration // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*chatHandlerFunctionsKeys*)
chatHandlerFunctionsKeys // beginDefinition;
chatHandlerFunctionsKeys[ as_? AssociationQ ] := chatHandlerFunctionsKeys[ as, as[ "HandlerFunctionsKeys" ] ];
chatHandlerFunctionsKeys[ as_, $$unspecified ] := $defaultHandlerKeys;
chatHandlerFunctionsKeys[ as_, keys_List ] := Union[ Select[ Flatten @ keys, StringQ ], $defaultHandlerKeys ];
chatHandlerFunctionsKeys[ as_, key_String ] := chatHandlerFunctionsKeys[ as, { key } ];
chatHandlerFunctionsKeys[ as_, invalid_ ] := (messagePrint[ "InvalidHandlerKeys", invalid ]; $defaultHandlerKeys);
chatHandlerFunctionsKeys // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*chatHandlers*)
chatHandlers // beginDefinition;
chatHandlers // Attributes = { HoldFirst };

chatHandlers[ container_, cellObject_, settings_ ] :=
    $lastHandlers = With[
        {
            autoOpen     = TrueQ @ $autoOpen,
            alwaysOpen   = TrueQ @ $alwaysOpen,
            autoAssist   = $autoAssistMode,
            dynamicSplit = dynamicSplitQ @ settings,
            handlers     = getHandlerFunctions @ settings
        },
        {
            bodyChunkHandler    = Lookup[ handlers, "BodyChunkReceived", None ],
            taskFinishedHandler = Lookup[ handlers, "TaskFinished"     , None ]
        },
        <|
            KeyDrop[ handlers, $chatSubmitDroppedHandlers ],
            "BodyChunkReceived" -> Function @ catchAlways[
                Block[
                    {
                        $autoOpen       = autoOpen,
                        $alwaysOpen     = alwaysOpen,
                        $settings       = settings,
                        $autoAssistMode = autoAssist,
                        $dynamicSplit   = dynamicSplit
                    },
                    bodyChunkHandler[ #1 ];
                    Internal`StuffBag[ $debugLog, $lastStatus = #1 ];
                    writeChunk[ Dynamic @ container, cellObject, #1 ]
                ]
            ],
            "TaskFinished" -> Function @ catchAlways[
                Block[
                    {
                        $autoOpen       = autoOpen,
                        $alwaysOpen     = alwaysOpen,
                        $settings       = settings,
                        $autoAssistMode = autoAssist,
                        $dynamicSplit   = dynamicSplit
                    },
                    taskFinishedHandler[ #1 ];
                    Internal`StuffBag[ $debugLog, $lastStatus = #1 ];
                    checkResponse[ settings, Unevaluated @ container, cellObject, #1 ]
                ]
            ]
        |>
    ];

chatHandlers // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*writeChunk*)
writeChunk // beginDefinition;

writeChunk[ container_, cell_, KeyValuePattern[ "BodyChunkProcessed" -> chunk_String ] ] :=
    writeChunk0[ container, cell, chunk, chunk ];

writeChunk[ container_, cell_, KeyValuePattern[ "BodyChunkProcessed" -> { chunks___String } ] ] :=
    With[ { chunk = StringJoin @ chunks },
        writeChunk0[ container, cell, chunk, chunk ]
    ];

(* TODO: this definition is obsolete once LLMServices is widely available: *)
writeChunk[ container_, cell_, KeyValuePattern[ "BodyChunk" -> chunk_String ] ] :=
    writeChunk[ container, cell, $buffer <> chunk ];

(* TODO: this definition is obsolete once LLMServices is widely available: *)
writeChunk[ container_, cell_, chunk_String ] :=
    Module[ { ws, sep, parts, buffer },
        ws      = WhitespaceCharacter...;
        sep     = "\n\n" | "\r\n\r\n";
        parts   = StringTrim @ StringCases[ chunk, "data:" ~~ ws ~~ json: Except[ "\n" ].. ~~ sep :> json ];
        buffer  = StringDelete[ StringDelete[ chunk, "data:" ~~ ws ~~ parts ~~ sep ], StartOfString ~~ "\n".. ];
        $buffer = buffer;
        writeChunk0[ container, cell, #1 ] & /@ parts
    ];

writeChunk // endDefinition;


writeChunk0 // beginDefinition;

(* TODO: this definition is obsolete once LLMServices is widely available: *)
writeChunk0[ container_, cell_, "" | "[DONE]" | "[DONE]\n\n" ] :=
    Null;

(* TODO: this definition is obsolete once LLMServices is widely available: *)
writeChunk0[ container_, cell_, chunk_String ] :=
    writeChunk0[ container, cell, chunk, Quiet @ Developer`ReadRawJSONString @ chunk ];

(* TODO: this definition is obsolete once LLMServices is widely available: *)
writeChunk0[
    container_,
    cell_,
    chunk_String,
    KeyValuePattern[ "choices" -> { KeyValuePattern[ "delta" -> KeyValuePattern[ "content" -> text_String ] ], ___ } ]
] := writeChunk0[ container, cell, chunk, text ];

(* TODO: this definition is obsolete once LLMServices is widely available: *)
writeChunk0[
    container_,
    cell_,
    chunk_String,
    KeyValuePattern[ "choices" -> { KeyValuePattern @ { "delta" -> <| |>, "finish_reason" -> "stop" }, ___ } ]
] := Null;

(* TODO: this definition is obsolete once LLMServices is widely available: *)
writeChunk0[
    container_,
    cell_,
    chunk_String,
    KeyValuePattern[ "completion" -> text_String ]
] := writeChunk0[ container, cell, chunk, text ];

writeChunk0[ Dynamic[ container_ ], cell_, chunk_String, text_String ] := (

    appendStringContent[ container[ "FullContent"    ], text ];
    appendStringContent[ container[ "DynamicContent" ], text ];

    (* FIXME: figure out what to do here when there's a custom formatter *)
    If[ TrueQ @ $dynamicSplit,
        (* Convert as much of the dynamic content as possible to static boxes and write to cell: *)
        splitDynamicContent[ container, cell ]
    ];

    If[ AbsoluteTime[ ] - $lastDynamicUpdate > 0.05,
        (* Trigger updating of dynamic content in current chat output cell *)
        $dynamicTrigger++;
        $lastDynamicUpdate = AbsoluteTime[ ]
    ];

    (* Handle auto-opening of assistant cells: *)
    Which[
        errorTaggedQ @ container, processErrorCell[ container, cell ],
        warningTaggedQ @ container, processWarningCell[ container, cell ],
        infoTaggedQ @ container, processInfoCell[ container, cell ],
        untaggedQ @ container, openChatCell @ cell,
        True, Null
    ]
);

writeChunk0[ Dynamic[ container_ ], cell_, chunk_String, other_ ] :=
     Internal`StuffBag[ $chunkDebug, <| "chunk" -> chunk, "other" -> other |> ];

writeChunk0 // endDefinition;

$chunkDebug = Internal`Bag[ ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*appendStringContent*)
appendStringContent // beginDefinition;
appendStringContent // Attributes = { HoldFirst };

appendStringContent[ container_, text_String ] :=
    If[ StringQ @ container,
        container = StringDelete[ container <> convertUTF8 @ text, StartOfString~~Whitespace ],
        container = convertUTF8 @ text
    ];

appendStringContent // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*splitDynamicContent*)
splitDynamicContent // beginDefinition;
splitDynamicContent // Attributes = { HoldFirst };

(* NotebookLocationSpecifier isn't available before 13.3 and splitting isn't yet supported in cloud: *)
splitDynamicContent[ container_, cell_ ] /; ! $dynamicSplit || $VersionNumber < 13.3 || $cloudNotebooks := Null;

splitDynamicContent[ container_, cell_ ] :=
    splitDynamicContent[ container, container[ "DynamicContent" ], cell, container[ "UUID" ] ];

splitDynamicContent[ container_, text_String, cell_, uuid_String ] :=
    splitDynamicContent[ container, StringSplit[ text, $dynamicSplitRules ], cell, uuid ];

splitDynamicContent[ container_, { static__String, dynamic_String }, cell_, uuid_String ] := Enclose[
    Catch @ Module[ { boxObject, reformatted, write, nbo },

        boxObject = ConfirmMatch[
            getBoxObjectFromBoxID[ cell, uuid ],
            _BoxObject | Missing[ "CellRemoved", ___ ],
            "BoxObject"
        ];

        If[ MatchQ[ boxObject, Missing[ "CellRemoved", ___ ] ],
            throwTop[ Quiet[ TaskRemove @ $lastTask, TaskRemove::timnf ]; Null ]
        ];

        reformatted = ConfirmMatch[
            Block[ { $dynamicText = False }, reformatTextData @ StringJoin @ static ],
            $$textDataList,
            "ReformatTextData"
        ];

        write = Cell[ TextData @ reformatted, Background -> None ];
        nbo = ConfirmMatch[ parentNotebook @ cell, _NotebookObject, "ParentNotebook" ];

        container[ "DynamicContent" ] = dynamic;

        With[ { boxObject = boxObject, write = write },
            splitDynamicTaskFunction @ NotebookWrite[
                System`NotebookLocationSpecifier[ boxObject, "Before" ],
                write,
                None,
                AutoScroll -> False
            ];
            splitDynamicTaskFunction @ NotebookWrite[
                System`NotebookLocationSpecifier[ boxObject, "Before" ],
                StyleBox[ "\n" ],
                None,
                AutoScroll -> False
            ];
        ];

        $dynamicTrigger++;
        $lastDynamicUpdate = AbsoluteTime[ ];

    ],
    throwInternalFailure[ splitDynamicContent[ container, { static, dynamic }, cell, uuid ], ## ] &
];

(* There's nothing we can write as static content yet: *)
splitDynamicContent[ container_, { _ } | { }, cell_, uuid_ ] := Null;

splitDynamicContent // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*checkResponse*)
checkResponse // beginDefinition;

checkResponse[ settings: KeyValuePattern[ "ToolsEnabled" -> False ], container_, cell_, as_Association ] :=
    If[ TrueQ @ $autoAssistMode,
        writeResult[ settings, container, cell, as ],
        $nextTaskEvaluation = Hold @ writeResult[ settings, container, cell, as ]
    ];

checkResponse[ settings_, container_? toolFreeQ, cell_, as_Association ] :=
    If[ TrueQ @ $autoAssistMode,
        writeResult[ settings, container, cell, as ],
        $nextTaskEvaluation = Hold @ writeResult[ settings, container, cell, as ]
    ];

checkResponse[ settings_, container_Symbol, cell_, as_Association ] :=
    If[ TrueQ @ $autoAssistMode,
        toolEvaluation[ settings, Unevaluated @ container, cell, as ],
        $nextTaskEvaluation = Hold @ toolEvaluation[ settings, Unevaluated @ container, cell, as ]
    ];

checkResponse // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*writeResult*)
writeResult // beginDefinition;

writeResult[ settings_, container_, cell_, as_Association ] :=
    Module[ { log, chunks, folded, body, data },

        log    = Internal`BagPart[ $debugLog, All ];
        chunks = Cases[ log, KeyValuePattern[ "BodyChunk" -> s: Except[ "", _String ] ] :> s ];
        folded = Fold[ StringJoin, chunks ];

        { body, data } = FirstCase[
            Flatten @ StringCases[
                folded,
                (StartOfString|"\n") ~~ "data: " ~~ s: Except[ "\n" ].. ~~ "\n" :> s
            ],
            s_String :> With[ { json = Quiet @ Developer`ReadRawJSONString @ s },
                            { s, json } /; MatchQ[ json, KeyValuePattern[ "error" -> _ ] ]
                        ],
            { Last[ folded, Missing[ "NotAvailable" ] ], Missing[ "NotAvailable" ] }
        ];

        If[ MatchQ[ as[ "StatusCode" ], Except[ 200, _Integer ] ] || AssociationQ @ data,
            writeErrorCell[ cell, $badResponse = Association[ as, "Body" -> body, "BodyJSON" -> data ] ],
            writeReformattedCell[ settings, container, cell ]
        ]
    ];

writeResult // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Tool Requests*)

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*toolFreeQ*)
toolFreeQ // beginDefinition;
toolFreeQ[ KeyValuePattern[ "FullContent" -> s_ ] ] := toolFreeQ @ s;
toolFreeQ[ _ProgressIndicator ] := True;
toolFreeQ[ s_String ] := ! MatchQ[ toolRequestParser @ s, { _, _LLMToolRequest|_Failure } ];
toolFreeQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*toolEvaluation*)
toolEvaluation // beginDefinition;

toolEvaluation[ settings_, container_Symbol, cell_, as_Association ] := Enclose[
    Module[ { string, callPos, toolCall, toolResponse, output, messages, newMessages, req, toolID },

        string = ConfirmBy[ container[ "FullContent" ], StringQ, "FullContent" ];

        { callPos, toolCall } = ConfirmMatch[
            toolRequestParser[ convertUTF8[ string, False ] ],
            { _, _LLMToolRequest|_Failure },
            "ToolRequestParser"
        ];

        toolResponse = ConfirmMatch[
            If[ FailureQ @ toolCall,
                toolCall,
                GenerateLLMToolResponse[ $toolConfiguration, toolCall ]
            ],
            _LLMToolResponse | _Failure,
            "GenerateLLMToolResponse"
        ];

        output = ConfirmBy[ toolResponseString @ toolResponse, StringQ, "ToolResponseString" ];

        messages = ConfirmMatch[ settings[ "Data", "Messages" ], { __Association }, "Messages" ];

        newMessages = Join[
            messages,
            {
                <| "role" -> "assistant", "content" -> StringTrim @ string <> "\nENDTOOLCALL" |>,
                <| "role" -> "system"   , "content" -> ToString @ output |>
            }
        ];

        req = If[ TrueQ @ $useLLMServices,
                  ConfirmMatch[ constructMessages[ settings, newMessages ], { __Association }, "ConstructMessages" ],
                  (* TODO: this path will be obsolete when LLMServices is widely available *)
                  ConfirmMatch[ makeHTTPRequest[ settings, newMessages ], _HTTPRequest, "HTTPRequest" ]
              ];

        toolID = Hash[ toolResponse, Automatic, "HexString" ];
        $toolEvaluationResults[ toolID ] = toolResponse;

        appendToolResult[ container, output, toolID ];

        $lastTask = chatSubmit[ container, req, cell, settings ]
    ],
    throwInternalFailure[ toolEvaluation[ settings, container, cell, as ], ## ] &
];

toolEvaluation // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*toolResponseString*)
toolResponseString // beginDefinition;
toolResponseString[ HoldPattern @ LLMToolResponse[ as_, ___ ] ] := toolResponseString @ as;
toolResponseString[ failed_Failure ] := ToString @ failed[ "Message" ];
toolResponseString[ as: KeyValuePattern[ "Output" -> output_ ] ] := toolResponseString[ as, output ];
toolResponseString[ as_, KeyValuePattern[ "String" -> output_ ] ] := toolResponseString[ as, output ];
toolResponseString[ as_, output_String ] := output;
toolResponseString[ as_, output_ ] := makeToolResponseString @ output;
toolResponseString // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*appendToolResult*)
appendToolResult // beginDefinition;
appendToolResult // Attributes = { HoldFirst };

(* cSpell: ignore ENDRESULT *)
appendToolResult[ container_Symbol, output_String, id_String ] :=
    Module[ { append },
        append = "ENDTOOLCALL\nRESULT\n"<>output<>"\nENDRESULT(" <> id <> ")\n\n";
        container[ "FullContent"    ] = container[ "FullContent"    ] <> append;
        container[ "DynamicContent" ] = container[ "DynamicContent" ] <> append;
    ];

appendToolResult // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Chat History*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*selectChatCells*)
selectChatCells // beginDefinition;

selectChatCells[ as_Association? AssociationQ, cell_CellObject, nbo_NotebookObject ] :=
    Block[
        {
            $maxChatCells = Replace[
                Lookup[ as, "ChatHistoryLength" ],
                Except[ _Integer? Positive ] :> $maxChatCells
            ]
        },
        $selectedChatCells = selectChatCells0[ cell, clearMinimizedChats @ nbo ]
    ];

selectChatCells // endDefinition;


selectChatCells0 // beginDefinition;

(* If `$finalCell` is defined, it means we are evaluating through the cell tray widget button. This can be invoked from
   a cell that is in the middle of other generated outputs, e.g. a message cell that lies between an input and output.
   In these cases, we want to make sure we don't delete chat output cells that come after the generated cells,
   since the user is just looking for chat feedback for the selected cell. *)
selectChatCells0[ cell_, cells: { __CellObject } ] := selectChatCells0[ cell, cells, $finalCell ];

(* If `$finalCell` is defined, we can use it to filter out any cells that follow it via this pattern: *)
selectChatCells0[ cell_, { before___, final_, ___ }, final_ ] := selectChatCells0[ cell, { before, final }, None ];

(* Otherwise, proceed with cell selection: *)
selectChatCells0[ cell_, cells: { __CellObject }, final_ ] := Enclose[
    Module[ { cellData, cellPosition, before, groupPos, selectedRange, filtered, rest, selectedCells },

        cellData = ConfirmMatch[
            cellInformation @ cells,
            { KeyValuePattern[ "CellObject" -> _CellObject ].. },
            "CellInformation"
        ];

        (* Position of the current evaluation cell *)
        cellPosition = ConfirmBy[
            First @ FirstPosition[ cellData, KeyValuePattern[ "CellObject" -> cell ] ],
            IntegerQ,
            "EvaluationCellPosition"
        ];

        (* Select all cells up to and including the evaluation cell *)
        before = Reverse @ Take[ cellData, cellPosition ];
        groupPos = ConfirmBy[
            First @ FirstPosition[
                before,
                Alternatives[
                    KeyValuePattern[ "Style" -> $$chatDelimiterStyle ],
                    KeyValuePattern[ "ChatNotebookSettings" -> KeyValuePattern[ "ChatDelimiter" -> True ] ]
                ],
                { Length @ before }
            ],
            IntegerQ,
            "ChatDelimiterPosition"
        ];
        selectedRange = Reverse @ Take[ before, groupPos ];

        (* Filter out ignored cells *)
        filtered = ConfirmMatch[ filterChatCells @ selectedRange, { ___Association }, "FilteredCellInfo" ];

        (* Delete output cells that come after the evaluation cell *)
        rest = deleteExistingChatOutputs @ Drop[ cellData, cellPosition ];

        (* Get the selected cell objects from the filtered cell info *)
        selectedCells = ConfirmMatch[
            Lookup[ Flatten @ { filtered, rest }, "CellObject" ],
            { __CellObject },
            "FilteredCellObjects"
        ];

        (* Limit the number of cells specified by ChatHistoryLength, starting from current cell and looking backwards *)
        ConfirmMatch[
            Reverse @ Take[ Reverse @ selectedCells, UpTo @ $maxChatCells ],
            { __CellObject },
            "ChatHistoryLengthCellObjects"
        ]
    ],
    throwInternalFailure[ selectChatCells0[ cell, cells, final ], ## ] &
];

selectChatCells0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*filterChatCells*)
filterChatCells // beginDefinition;

filterChatCells[ cellInfo: { ___Association } ] := Enclose[
    Module[ { styleExcluded, tagExcluded, cells },

        styleExcluded = DeleteCases[ cellInfo, KeyValuePattern[ "Style" -> $$chatIgnoredStyle ] ];

        tagExcluded = DeleteCases[
            styleExcluded,
            KeyValuePattern[ "ChatNotebookSettings" -> KeyValuePattern[ "ExcludeFromChat" -> True ] ]
        ];

        tagExcluded
    ],
    throwInternalFailure[ filterChatCells @ cellInfo, ## ] &
];

filterChatCells // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*deleteExistingChatOutputs*)
deleteExistingChatOutputs // beginDefinition;

(* When chat is triggered by an evaluation instead of a chat input, there can be generated cells between the
   evaluation cell and the previous chat output. For example:

       CellObject[ <Current evaluation cell> ]
       CellObject[ <Message/Print/Echo cells, etc.> ]
       CellObject[ <Output from the current evaluation cell> ]
       CellObject[ <Previous chat output> ] <--- We want to delete this cell, since it's from a previous evaluation

   At this point, the front end has already cleared previous output cells (messages, output, etc.), but the previous
   chat output cell is still there. We need to delete it so that the new chat output cell can be inserted in its place.
   `deleteExistingChatOutputs` gathers up all the generated cells that come after the evaluation cell and if it finds
   a chat output cell, it deletes it.
*)
deleteExistingChatOutputs[ cellData: { KeyValuePattern[ "CellObject" -> _CellObject ] ... } ] /; $autoAssistMode :=
    Module[ { delete, chatOutputs, cells },
        delete      = TakeWhile[ cellData, MatchQ @ KeyValuePattern[ "CellAutoOverwrite" -> True ] ];
        chatOutputs = Cases[ delete, KeyValuePattern[ "Style" -> $$chatOutputStyle ] ];
        cells       = Cases[ chatOutputs, KeyValuePattern[ "CellObject" -> cell_ ] :> cell ];
        NotebookDelete @ cells;
        DeleteCases[ delete, KeyValuePattern[ "CellObject" -> Alternatives @@ cells ] ]
    ];

deleteExistingChatOutputs[ cellData_ ] :=
    TakeWhile[ cellData, MatchQ @ KeyValuePattern[ "CellAutoOverwrite" -> True ] ];

deleteExistingChatOutputs // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*chatHistoryCellsAndTarget*)
chatHistoryCellsAndTarget // beginDefinition;

chatHistoryCellsAndTarget[ { before___CellObject, after_CellObject } ] :=
    If[ MatchQ[ cellInformation @ after, KeyValuePattern[ "Style" -> $$chatOutputStyle ] ],
        { { before }, after },
        { { before, after }, None }
    ];

chatHistoryCellsAndTarget // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Settings*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*inheritSettings*)
inheritSettings // beginDefinition;

inheritSettings[ settings_, { first_CellObject, ___ }, evalCell_CellObject ] :=
    inheritSettings[ settings, cellInformation @ first, evalCell ];

inheritSettings[
    settings_Association,
    KeyValuePattern @ { "Style" -> $$chatDelimiterStyle, "CellObject" -> delimiter_CellObject },
    evalCell_CellObject
] := mergeSettings[ settings, currentChatSettings @ delimiter, currentChatSettings @ evalCell ];

inheritSettings[ settings_Association, _, evalCell_CellObject ] :=
    mergeSettings[ settings, <| |>, currentChatSettings @ evalCell ];

inheritSettings // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*mergeSettings*)
mergeSettings // beginDefinition;

mergeSettings[ settings_? AssociationQ, group_? AssociationQ, cell_? AssociationQ ] :=
    Module[ { as },
        as = Association[ settings, Complement[ group, settings ], Complement[ cell, settings ] ];
        Association[ as, "LLMEvaluator" -> getLLMEvaluator @ as ]
    ];\

mergeSettings // endDefinition;\

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*getLLMEvaluator*)
getLLMEvaluator // beginDefinition;
getLLMEvaluator[ as_Association ] := getLLMEvaluator[ as, Lookup[ as, "LLMEvaluator" ] ];
getLLMEvaluator[ as_, name_String ] :=
    (* If there isn't any information on `name`, getNamedLLMEvaluator just
        returns `name`; if that happens, avoid infinite recursion by just
        returning *)
    Replace[getNamedLLMEvaluator[name], {
        name -> name,
        other_ :> getLLMEvaluator[as, other]
    }]
getLLMEvaluator[ as_, evaluator_Association ] := evaluator;
getLLMEvaluator[ _, _ ] := None;
getLLMEvaluator // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*getNamedLLMEvaluator*)
getNamedLLMEvaluator // beginDefinition;
getNamedLLMEvaluator[ name_String ] := getNamedLLMEvaluator[ name, GetCachedPersonaData @ name ];
getNamedLLMEvaluator[ name_String, evaluator_Association ] := Append[ evaluator, "LLMEvaluatorName" -> name ];
getNamedLLMEvaluator[ name_String, _ ] := name;
getNamedLLMEvaluator // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*resolveAutoSettings*)
resolveAutoSettings // beginDefinition;

resolveAutoSettings[ settings: KeyValuePattern[ key_ :> value_ ] ] :=
    resolveAutoSettings @ Association[ settings, key -> value ];

resolveAutoSettings[ settings: KeyValuePattern[ "ToolsEnabled" -> Automatic ] ] :=
    resolveAutoSettings @ Association[ settings, "ToolsEnabled" -> toolsEnabledQ @ settings ];

resolveAutoSettings[ settings_Association ] := settings;

resolveAutoSettings // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*toolsEnabledQ*)
(*FIXME: move to Tools.wl *)
toolsEnabledQ[ KeyValuePattern[ "ToolsEnabled" -> enabled: True|False ] ] := enabled;
toolsEnabledQ[ KeyValuePattern[ "Model" -> model_ ] ] := toolsEnabledQ @ toModelName @ model;
toolsEnabledQ[ model_String ] := ! TrueQ @ StringStartsQ[ model, "gpt-3", IgnoreCase -> True ];
toolsEnabledQ[ ___ ] := False;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*dynamicSplitQ*)
dynamicSplitQ // beginDefinition;
dynamicSplitQ[ as_Association ] := dynamicSplitQ @ Lookup[ as, "StreamingOutputMethod", Automatic ];
dynamicSplitQ[ sym_Symbol ] := dynamicSplitQ @ SymbolName @ sym;
dynamicSplitQ[ "PartialDynamic"|"Automatic"|"Inherited" ] := True;
dynamicSplitQ[ "FullDynamic"|"Dynamic" ] := False;
dynamicSplitQ[ other_ ] := (messagePrint[ "InvalidStreamingOutputMethod", other ]; True);
dynamicSplitQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*AutoAssistant Processing*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Tags*)

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*errorTaggedQ*)
errorTaggedQ // ClearAll;
errorTaggedQ[ s_  ] := taggedQ[ s, "ERROR" ];
errorTaggedQ[ ___ ] := False;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*warningTaggedQ*)
warningTaggedQ // ClearAll;
warningTaggedQ[ s_  ] := taggedQ[ s, "WARNING" ];
warningTaggedQ[ ___ ] := False;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*infoTaggedQ*)
infoTaggedQ // ClearAll;
infoTaggedQ[ s_  ] := taggedQ[ s, "INFO" ];
infoTaggedQ[ ___ ] := False;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*untaggedQ*)
untaggedQ // ClearAll;
untaggedQ[ as_Association? AssociationQ ] := untaggedQ @ as[ "FullContent" ];
untaggedQ[ s0_String? StringQ ] /; $alwaysOpen :=
    With[ { s = StringDelete[ $lastUntagged = s0, Whitespace ] },
        Or[ StringStartsQ[ s, Except[ "[" ] ],
            StringLength @ s >= $maxTagLength && ! StringStartsQ[ s, $$tagPrefix, IgnoreCase -> True ]
        ]
    ];

untaggedQ[ ___ ] := False;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*taggedQ*)
taggedQ // ClearAll;
taggedQ[ s_ ] := taggedQ[ s, $$severityTag ];
taggedQ[ as_Association? AssociationQ, tag_ ] := taggedQ[ as[ "FullContent" ], tag ];
taggedQ[ s_String? StringQ, tag_ ] := StringStartsQ[ StringDelete[ s, Whitespace ], "["~~tag~~"]", IgnoreCase -> True ];
taggedQ[ ___ ] := False;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*removeSeverityTag*)
removeSeverityTag // beginDefinition;
removeSeverityTag // Attributes = { HoldFirst };

removeSeverityTag[ s_Symbol? AssociationQ, cell_CellObject ] /; StringQ @ s[ "FullContent" ] :=
    Module[ { tag },
        tag = StringReplace[ s[ "FullContent" ], t:$$tagPrefix~~___~~EndOfString :> t ];
        s = untagString @ s;
        CurrentValue[ cell, { TaggingRules, "MessageTag" } ] = ToUpperCase @ StringDelete[ tag, Whitespace ]
    ];

removeSeverityTag // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*untagString*)
untagString // beginDefinition;

untagString[ as: KeyValuePattern @ { "FullContent" -> full_, "DynamicContent" -> dynamic_ } ] :=
    Association[ as, "FullContent" -> untagString @ full, "DynamicContent" -> untagString @ dynamic ];

untagString[ str_String? StringQ ] := StringDelete[ str, $$tagPrefix, IgnoreCase -> True ];

untagString // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Minimized Assistant Cells*)

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*processErrorCell*)
processErrorCell // beginDefinition;
processErrorCell // Attributes = { HoldFirst };

processErrorCell[ container_, cell_CellObject ] := (
    removeSeverityTag[ container, cell ];
    SetOptions[ cell, "AssistantOutputError" ];
    openChatCell @ cell
);

processErrorCell // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*processWarningCell*)
processWarningCell // beginDefinition;
processWarningCell // Attributes = { HoldFirst };

processWarningCell[ container_, cell_CellObject ] := (
    removeSeverityTag[ container, cell ];
    SetOptions[ cell, "AssistantOutputWarning" ];
    openChatCell @ cell
);

processWarningCell // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*processInfoCell*)
processInfoCell // beginDefinition;
processInfoCell // Attributes = { HoldFirst };

processInfoCell[ container_, cell_CellObject ] := (
    removeSeverityTag[ container, cell ];
    SetOptions[ cell, "AssistantOutput" ];
    $lastAutoOpen = $autoOpen;
    If[ TrueQ @ $autoOpen, openChatCell @ cell ]
);

processInfoCell // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*openChatCell*)
openChatCell // beginDefinition;

openChatCell[ cell_CellObject ] :=
    Module[ { prev, attached },
        prev = PreviousCell @ cell;
        attached = Cells[ prev, AttachedCell -> True, CellStyle -> "MinimizedChatIcon" ];
        NotebookDelete @ attached;
        SetOptions[
            cell,
            CellMargins     -> Inherited,
            CellOpen        -> Inherited,
            CellFrame       -> Inherited,
            ShowCellBracket -> Inherited,
            Initialization  -> Inherited
        ]
    ];

openChatCell // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Cells*)

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*createNewChatOutput*)
createNewChatOutput // beginDefinition;
createNewChatOutput[ settings_, None, cell_Cell ] := cellPrint @ cell;
createNewChatOutput[ settings_, target_, cell_Cell ] /; settings[ "TabbedOutput" ] === False := cellPrint @ cell;
createNewChatOutput[ settings_, target_CellObject, cell_Cell ] := prepareChatOutputPage[ target, cell ];
createNewChatOutput // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*prepareChatOutputPage*)
prepareChatOutputPage // beginDefinition;

prepareChatOutputPage[ target_CellObject, cell_Cell ] := Enclose[
    Module[ { prevCellExpr, prevPage, encoded, pageData, newCellObject },

        prevCellExpr = ConfirmMatch[ NotebookRead @ target, _Cell, "NotebookRead" ];

        prevPage = ConfirmMatch[
            Replace[ First @ prevCellExpr, text_String :> TextData @ { text } ],
            _TextData,
            "PageContent"
        ];

        encoded = ConfirmBy[
            BaseEncode @ BinarySerialize[ prevPage, PerformanceGoal -> "Size" ],
            StringQ,
            "BaseEncode"
        ];

        pageData = ConfirmBy[
            Replace[
                prevCellExpr,
                {
                    Cell[ __, TaggingRules -> KeyValuePattern[ "PageData" -> data_ ], ___ ] :> Association @ data,
                    _ :> <| |>
                }
            ],
            AssociationQ,
            "PageData"
        ];

        If[ ! AssociationQ @ pageData[ "Pages" ], pageData[ "Pages" ] = <| 1 -> encoded |> ];
        If[ ! IntegerQ @ pageData[ "PageCount" ], pageData[ "PageCount" ] = 1 ];
        If[ ! IntegerQ @ pageData[ "CurrentPage" ], pageData[ "CurrentPage" ] = 1 ];
        pageData[ "PagedOutput" ] = True;

        newCellObject = cellPrint @ cell;
        CurrentValue[ newCellObject, { TaggingRules, "PageData" } ] = pageData;
        newCellObject
    ],
    throwInternalFailure[ prepareChatOutputPage[ target, cell ], ## ] &
];

prepareChatOutputPage // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*activeAIAssistantCell*)
activeAIAssistantCell // beginDefinition;
activeAIAssistantCell // Attributes = { HoldFirst };

activeAIAssistantCell[ container_, settings_Association? AssociationQ ] :=
    activeAIAssistantCell[ container, settings, Lookup[ settings, "ShowMinimized", Automatic ] ];

activeAIAssistantCell[
    container_,
    settings: KeyValuePattern[ "CellObject" :> cellObject_ ],
    minimized_
] /; $cloudNotebooks :=
    With[
        {
            label     = RawBoxes @ TemplateBox[ { }, "MinimizedChatActive" ],
            id        = $SessionID,
            reformat  = dynamicAutoFormatQ @ settings,
            task      = Lookup[ settings, "Task" ],
            formatter = getFormattingFunction @ settings
        },
        Module[ { x = 0 },
            ClearAttributes[ { x, cellObject }, Temporary ];
            Cell[
                BoxData @ ToBoxes @
                    If[ TrueQ @ reformat,
                        Dynamic[
                            Refresh[
                                x++;
                                If[ MatchQ[ $reformattedCell, _Cell ],
                                    Pause[ 1 ];
                                    NotebookWrite[ cellObject, $reformattedCell ];
                                    Remove[ x, cellObject ];
                                    ,
                                    catchTop @ dynamicTextDisplay[ container, formatter, reformat ]
                                ],
                                TrackedSymbols :> { x },
                                UpdateInterval -> 0.4
                            ],
                            Initialization   :> If[ $SessionID =!= id, NotebookDelete @ EvaluationCell[ ] ],
                            Deinitialization :> Quiet @ TaskRemove @ task
                        ],
                        Dynamic[
                            x++;
                            If[ MatchQ[ $reformattedCell, _Cell ],
                                Pause[ 1 ];
                                NotebookWrite[ cellObject, $reformattedCell ];
                                Remove[ x, cellObject ];
                                ,
                                catchTop @ dynamicTextDisplay[ container, formatter, reformat ]
                            ],
                            Initialization   :> If[ $SessionID =!= id, NotebookDelete @ EvaluationCell[ ] ],
                            Deinitialization :> Quiet @ TaskRemove @ task
                        ]
                    ],
                "Output",
                "ChatOutput",
                Sequence @@ Flatten[ { $closedChatCellOptions } ],
                Selectable   -> False,
                Editable     -> False,
                CellDingbat  -> Cell[ BoxData @ makeActiveOutputDingbat @ settings, Background -> None ],
                TaggingRules -> <| "ChatNotebookSettings" -> settings |>
            ]
        ]
    ];

activeAIAssistantCell[
    container_,
    settings: KeyValuePattern[ "CellObject" :> cellObject_ ],
    minimized_
] :=
    With[
        {
            label     = RawBoxes @ TemplateBox[ { }, "MinimizedChatActive" ],
            id        = $SessionID,
            reformat  = dynamicAutoFormatQ @ settings,
            task      = Lookup[ settings, "Task" ],
            uuid      = container[ "UUID" ],
            formatter = getFormattingFunction @ settings
        },
        Cell[
            BoxData @ TagBox[
                ToBoxes @ Dynamic[
                    $dynamicTrigger;
                    (* `$dynamicTrigger` is used to precisely control when the dynamic updates, otherwise we can get an
                       FE crash if a NotebookWrite happens at the same time. *)
                    catchTop @ dynamicTextDisplay[ container, formatter, reformat ],
                    TrackedSymbols   :> { $dynamicTrigger },
                    Initialization   :> If[ $SessionID =!= id, NotebookDelete @ EvaluationCell[ ] ],
                    Deinitialization :> Quiet @ TaskRemove @ task
                ],
                "DynamicTextDisplay",
                BoxID -> uuid
            ]
            ,
            "Output",
            "ChatOutput",
            ShowAutoSpellCheck -> False,
            CodeAssistOptions -> { "AutoDetectHyperlinks" -> False },
            LanguageCategory -> None,
            LineIndent -> 0,
            If[ TrueQ @ $autoAssistMode && MatchQ[ minimized, True|Automatic ],
                Sequence @@ Flatten[ {
                    $closedChatCellOptions,
                    Initialization :> catchTop @ attachMinimizedIcon[ EvaluationCell[ ], label ]
                } ],
                Initialization -> None
            ],
            CellDingbat       -> Cell[ BoxData @ makeActiveOutputDingbat @ settings, Background -> None ],
            CellEditDuplicate -> False,
            Editable          -> True,
            Selectable        -> True,
            ShowCursorTracker -> False,
            TaggingRules      -> <| "ChatNotebookSettings" -> settings |>
        ]
    ];

activeAIAssistantCell // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*getFormattingFunction*)
getFormattingFunction // beginDefinition;
getFormattingFunction[ as_? AssociationQ ] := getFormattingFunction[ as, as[ "ChatFormattingFunction" ] ];
getFormattingFunction[ as_, $$unspecified ] := FormatChatOutput;
getFormattingFunction[ as_, func_ ] := replaceCellContext @ func;
getFormattingFunction // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*dynamicAutoFormatQ*)
dynamicAutoFormatQ // beginDefinition;
dynamicAutoFormatQ[ KeyValuePattern[ "DynamicAutoFormat" -> format: (True|False) ] ] := format;
dynamicAutoFormatQ[ KeyValuePattern[ "AutoFormat" -> format_ ] ] := TrueQ @ format;
dynamicAutoFormatQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*dynamicTextDisplay*)
dynamicTextDisplay // beginDefinition;
dynamicTextDisplay // Attributes = { HoldFirst };

dynamicTextDisplay[ container_, formatter_, reformat_ ] /; $highlightDynamicContent :=
    Block[ { $highlightDynamicContent = False },
        Framed[ dynamicTextDisplay[ container, formatter, reformat ], FrameStyle -> Purple ]
    ];

dynamicTextDisplay[ container_, formatter_, True ] :=
    If[ StringQ @ container[ "DynamicContent" ],
        formatter[ container[ "DynamicContent" ], <| "Status" -> "Streaming", "Container" :> container |> ],
        formatter[ container[ "DynamicContent" ], <| "Status" -> "Waiting"  , "Container" :> container |> ]
    ];

dynamicTextDisplay[ container_, formatter_, False ] /; StringQ @ container[ "DynamicContent" ] :=
    RawBoxes @ Cell @ TextData @ container[ "DynamicContent" ];

dynamicTextDisplay[ _Symbol, _, _ ] := ProgressIndicator[ Appearance -> "Percolate" ];

dynamicTextDisplay[ other_, _, _ ] := other;

dynamicTextDisplay // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*makeActiveOutputDingbat*)
makeActiveOutputDingbat // beginDefinition;

makeActiveOutputDingbat[ as: KeyValuePattern[ "LLMEvaluator" -> config_ ] ] := makeActiveOutputDingbat[ as, config ];
makeActiveOutputDingbat[ as_, KeyValuePattern[ "PersonaIcon" -> icon_ ] ] := makeActiveOutputDingbat[ as, icon ];
makeActiveOutputDingbat[ as_, KeyValuePattern[ "Icon" -> icon_ ] ] := makeActiveOutputDingbat[ as, icon ];

makeActiveOutputDingbat[ as_, KeyValuePattern[ "Active" -> icon_ ] ] :=
    Block[ { $noActiveProgress = True }, makeActiveOutputDingbat[ as, icon ] ];

makeActiveOutputDingbat[ as_, KeyValuePattern[ "Default" -> icon_ ] ] :=
    makeActiveOutputDingbat[ as, icon ];

makeActiveOutputDingbat[ as_, _Association|_Missing|_Failure|None ] :=
    makeActiveOutputDingbat[ as, RawBoxes @ TemplateBox[ { }, "AssistantIconActive" ] ];

makeActiveOutputDingbat[ as_, icon_ ] :=
    If[ TrueQ @ $noActiveProgress,
        TemplateBox[ { toDingbatBoxes @ resizeDingbat @ icon }, "ChatOutputStopButtonWrapper" ],
        TemplateBox[ { toDingbatBoxes @ resizeDingbat @ icon }, "ChatOutputStopButtonProgressWrapper" ]
    ];

makeActiveOutputDingbat // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*makeOutputDingbat*)
makeOutputDingbat // beginDefinition;
makeOutputDingbat[ as: KeyValuePattern[ "LLMEvaluator" -> config_Association ] ] := makeOutputDingbat[ as, config ];
makeOutputDingbat[ as_Association ] := makeOutputDingbat[ as, as ];
makeOutputDingbat[ as_, KeyValuePattern[ "PersonaIcon" -> icon_ ] ] := makeOutputDingbat[ as, icon ];
makeOutputDingbat[ as_, KeyValuePattern[ "Icon" -> icon_ ] ] := makeOutputDingbat[ as, icon ];
makeOutputDingbat[ as_, KeyValuePattern[ "Default" -> icon_ ] ] := makeOutputDingbat[ as, icon ];
makeOutputDingbat[ as_, _Association|_Missing|_Failure|None ] := TemplateBox[ { }, "AssistantIcon" ];
makeOutputDingbat[ as_, icon_ ] := toDingbatBoxes @ resizeDingbat @ icon;
makeOutputDingbat // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*resizeDingbat*)
resizeDingbat // beginDefinition;

resizeDingbat[ icon_ ] /; $resizeDingbats := Pane[
    icon,
    ContentPadding  -> False,
    FrameMargins    -> 0,
    ImageSize       -> { 35, 35 },
    ImageSizeAction -> "ShrinkToFit",
    Alignment       -> { Center, Center }
];

resizeDingbat[ icon_ ] := icon;

resizeDingbat // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*toDingbatBoxes*)
toDingbatBoxes // beginDefinition;
toDingbatBoxes[ icon_ ] := toDingbatBoxes[ icon ] = toCompressedBoxes @ icon;
toDingbatBoxes // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*writeReformattedCell*)
writeReformattedCell // beginDefinition;

writeReformattedCell[ settings_, KeyValuePattern[ "FullContent" -> string_ ], cell_ ] :=
    writeReformattedCell[ settings, string, cell ];

writeReformattedCell[ settings_, _ProgressIndicator, cell_CellObject ] :=
    writeReformattedCell[ settings, None, cell ];

writeReformattedCell[ settings_, None, cell_CellObject ] :=
    With[ { taggingRules = Association @ CurrentValue[ cell, TaggingRules ] },
        $lastChatString = None;
        If[ AssociationQ @ taggingRules[ "PageData" ],
            restoreLastPage[ settings, taggingRules, cell ],
            NotebookDelete @ cell
        ]
    ];

writeReformattedCell[ settings_, string_String, cell_CellObject ] := Enclose[
    Block[ { $dynamicText = False },
        Module[ { tag, open, label, pageData, uuid, new, output },

            tag      = ConfirmMatch[ CurrentValue[ cell, { TaggingRules, "MessageTag" } ], _String|Inherited, "Tag" ];
            open     = $lastOpen = cellOpenQ @ cell;
            label    = RawBoxes @ TemplateBox[ { }, "MinimizedChat" ];
            pageData = CurrentValue[ cell, { TaggingRules, "PageData" } ];
            uuid     = CreateUUID[ ];
            new      = reformatCell[ settings, string, tag, open, label, pageData, uuid ];
            output   = CellObject @ uuid;

            $lastChatString  = string;
            $reformattedCell = new;
            $lastChatOutput  = output;

            With[ { new = new, output = output },
                If[ TrueQ[ $VersionNumber >= 14.0 ],
                    createFETask @ NotebookWrite[ cell, new, None, AutoScroll -> False ];
                    createFETask @ attachChatOutputMenu @ output;
                    createFETask @ postApply[ output, string, settings ];
                    ,
                    NotebookWrite[ cell, new, None, AutoScroll -> False ];
                    attachChatOutputMenu @ output;
                    postApply[ output, string, settings ];
                ]
            ]
        ]
    ],
    throwInternalFailure[ writeReformattedCell[ settings, string, cell ], ## ] &
];

writeReformattedCell[ settings_, other_, cell_CellObject ] :=
    createFETask @ NotebookWrite[
        cell,
        Cell[
            TextData @ {
                "An unexpected error occurred.\n\n",
                Cell @ BoxData @ ToBoxes @ catchAlways @ throwInternalFailure @
                    writeReformattedCell[ settings, other, cell ]
            },
            "ChatOutput",
            GeneratedCell     -> True,
            CellAutoOverwrite -> True
        ],
        None,
        AutoScroll -> False
    ];

writeReformattedCell // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*postApply*)
postApply // beginDefinition;

postApply[ output_CellObject, string_, settings_Association ] :=
    postApply0[
        getHandlerFunction[ settings, "ChatPost" ],
        <|
            "EvaluationCell"       -> output,
            "Result"               -> string,
            "ChatNotebookSettings" -> KeyDrop[ settings, { "Data", "OpenAIKey" } ],
            Replace[ Lookup[ settings, "Data" ], Except[ _? AssociationQ ] -> <| |> ]
        |>
    ];

postApply // endDefinition;

postApply0 // beginDefinition;
postApply0[ post_, data_Association? AssociationQ ] := post @ data;
postApply0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*reformatCell*)
reformatCell // beginDefinition;

reformatCell[ settings_, string_, tag_, open_, label_, pageData_, uuid_ ] := UsingFrontEnd @ Enclose[
    Module[ { formatter, content, rules, dingbat },

        formatter = Confirm[ getFormattingFunction @ settings, "GetFormattingFunction" ];

        (*FIXME: use specified ChatFormattingFunction here and figure out how to conform to TextData *)
        content = ConfirmMatch[
            If[ TrueQ @ settings[ "AutoFormat" ],
                TextData @ reformatTextData @ string,
                TextData @ string
            ],
            TextData[ _String | _List ],
            "Content"
        ];

        rules = ConfirmBy[
            makeReformattedCellTaggingRules[ settings, string, tag, content, pageData ],
            AssociationQ,
            "TaggingRules"
        ];

        dingbat = makeOutputDingbat @ settings;

        Cell[
            content,
            If[ TrueQ @ $autoAssistMode,
                Switch[ tag,
                        "[ERROR]"  , "AssistantOutputError",
                        "[WARNING]", "AssistantOutputWarning",
                        _          , "AssistantOutput"
                ],
                "ChatOutput"
            ],
            GeneratedCell     -> True,
            CellAutoOverwrite -> True,
            TaggingRules      -> rules,
            If[ TrueQ[ rules[ "PageData", "PageCount" ] > 1 ],
                CellDingbat -> Cell[ BoxData @ TemplateBox[ { dingbat }, "AssistantIconTabbed" ], Background -> None ],
                CellDingbat -> Cell[ BoxData @ dingbat, Background -> None ]
            ],
            If[ TrueQ @ open,
                Sequence @@ { },
                Sequence @@ Flatten @ {
                    $closedChatCellOptions,
                    Initialization :> attachMinimizedIcon[ EvaluationCell[ ], label ]
                }
            ],
            ExpressionUUID -> uuid
        ]
    ],
    throwInternalFailure[ reformatCell[ settings, string, tag, open, label, pageData, uuid ], ## ] &
];

reformatCell // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*attachMinimizedIcon*)
attachMinimizedIcon // beginDefinition;

attachMinimizedIcon[ chatCell_CellObject, label_ ] :=
    Module[ { prev, cell },
        prev = PreviousCell @ chatCell;
        CurrentValue[ chatCell, Initialization ] = Inherited;
        cell = makeMinimizedIconCell[ label, chatCell ];
        NotebookDelete @ Cells[ prev, AttachedCell -> True, CellStyle -> "MinimizedChatIcon" ];
        With[ { prev = prev, cell = cell },
            If[ TrueQ @ BoxForm`sufficientVersionQ[ 13.2 ],
                FE`Evaluate @ FEPrivate`AddCellTrayWidget[ prev, "MinimizedChatIcon" -> <| "Content" -> cell |> ],
                AttachCell[ prev, cell, { "CellBracket", Top }, { 0, 0 }, { Right, Top } ]
            ]
        ]
    ];

attachMinimizedIcon // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*makeMinimizedIconCell*)
makeMinimizedIconCell // beginDefinition;

makeMinimizedIconCell[ label_, chatCell_CellObject ] := Cell[
    BoxData @ MakeBoxes @ Button[
        MouseAppearance[ label, "LinkHand" ],
        With[ { attached = EvaluationCell[ ] }, NotebookDelete @ attached; openChatCell @ chatCell ],
        Appearance -> None
    ],
    "MinimizedChatIcon"
];

makeMinimizedIconCell // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*makeReformattedCellTaggingRules*)
makeReformattedCellTaggingRules // beginDefinition;

makeReformattedCellTaggingRules[
    settings_,
    string_,
    tag: _String|Inherited,
    content_,
    KeyValuePattern @ { "Pages" -> pages_Association, "PageCount" -> count_Integer, "CurrentPage" -> page_Integer }
] :=
    With[ { p = count + 1 },
    <|
        "CellToStringData" -> string,
        "MessageTag"       -> tag,
        "ChatData"         -> makeCompactChatData[ string, tag, settings ],
        "PageData"         -> <|
            "Pages"      -> Append[ pages, p -> BaseEncode @ BinarySerialize[ content, PerformanceGoal -> "Size" ] ],
            "PageCount"  -> p,
            "CurrentPage"-> p
        |>
    |>
];

makeReformattedCellTaggingRules[ settings_, string_, tag: _String|Inherited, content_, pageData_ ] := <|
    "CellToStringData" -> string,
    "MessageTag"       -> tag,
    "ChatData"         -> makeCompactChatData[ string, tag, settings ]
|>;

makeReformattedCellTaggingRules // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*makeCompactChatData*)
makeCompactChatData // beginDefinition;

makeCompactChatData[ message_, tag_, as_ ] /; $cloudNotebooks := Inherited;

makeCompactChatData[
    message_,
    tag_,
    as: KeyValuePattern[ "Data" -> data: KeyValuePattern[ "Messages" -> messages_List ] ]
] :=
    BaseEncode @ BinarySerialize[
        Association[
            smallSettings @ KeyDrop[ as, "OpenAIKey" ],
            "MessageTag" -> tag,
            "Data" -> Association[
                data,
                "Messages" -> Append[ messages, <| "role" -> "assistant", "content" -> message |> ]
            ]
        ],
        PerformanceGoal -> "Size"
    ];

makeCompactChatData // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*smallSettings*)
smallSettings // beginDefinition;
smallSettings[ as_Association ] := smallSettings[ as, as[ "LLMEvaluator" ] ];
smallSettings[ as_, KeyValuePattern[ "LLMEvaluatorName" -> name_String ] ] := Append[ as, "LLMEvaluator" -> name ];
smallSettings[ as_, _ ] := as;
smallSettings // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*restoreLastPage*)
restoreLastPage // beginDefinition;

restoreLastPage[ settings_, rules_Association, cellObject_CellObject ] := Enclose[
    Module[ { pageData, b64, bytes, content, dingbat, uuid, cell },

        pageData = ConfirmBy[ rules[ "PageData" ], AssociationQ, "PageData" ];
        b64      = ConfirmBy[ pageData[ "Pages", pageData[ "CurrentPage" ] ], StringQ, "Base64" ];
        bytes    = ConfirmBy[ ByteArray @ b64, ByteArrayQ, "ByteArray" ];
        content  = ConfirmMatch[ BinaryDeserialize @ bytes, _TextData, "TextData" ];
        dingbat  = makeOutputDingbat @ settings;
        uuid     = CreateUUID[ ];

        cell = Cell[
            content,
            "ChatOutput",
            GeneratedCell     -> True,
            CellAutoOverwrite -> True,
            TaggingRules      -> rules,
            ExpressionUUID    -> uuid,
            If[ TrueQ[ rules[ "PageData", "PageCount" ] > 1 ],
                CellDingbat -> Cell[ BoxData @ TemplateBox[ { dingbat }, "AssistantIconTabbed" ], Background -> None ],
                CellDingbat -> Cell[ BoxData @ dingbat, Background -> None ]
            ]
        ];

        createFETask @ WithCleanup[
            NotebookWrite[
                cellObject,
                $reformattedCell = cell,
                None,
                AutoScroll -> False
            ],
            attachChatOutputMenu[ $lastChatOutput = CellObject @ uuid ]
        ]
    ],
    throwInternalFailure[ restoreLastPage[ settings, rules, cellObject ], ## ] &
];

restoreLastPage // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*attachChatOutputMenu*)
attachChatOutputMenu // beginDefinition;

attachChatOutputMenu[ cell_CellObject ] /; $cloudNotebooks := Null;

attachChatOutputMenu[ cell_CellObject ] := (
    $lastChatOutput = cell;
    NotebookDelete @ Cells[ cell, AttachedCell -> True, CellStyle -> "ChatMenu" ];
    AttachCell[
        cell,
        Cell[ BoxData @ TemplateBox[ { "ChatOutput", RGBColor[ "#ecf0f5" ] }, "ChatMenuButton" ], "ChatMenu" ],
        { Right, Top },
        Offset[ { -7, -7 }, { Right, Top } ],
        { Right, Top }
    ]
);

attachChatOutputMenu // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*writeErrorCell*)
writeErrorCell // beginDefinition;
writeErrorCell[ cell_, failure_Failure ] := (createFETask @ NotebookDelete @ cell; failure);
writeErrorCell[ cell_, as_ ] := (createFETask @ NotebookWrite[ cell, errorCell @ as ]; Null);
writeErrorCell // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*errorCell*)
errorCell // beginDefinition;

errorCell[ failure_Failure ] :=
    Cell[ BoxData @ ToBoxes @ failure, "Output" ];

errorCell[ as_ ] :=
    Cell[
        TextData @ Flatten @ {
            StyleBox[ "\[WarningSign] ", FontColor -> Darker @ Red, FontSize -> 1.5 Inherited ],
            errorText @ as,
            "\n\n",
            Cell @ BoxData @ errorBoxes @ as
        },
        "Text",
        "ChatOutput",
        GeneratedCell     -> True,
        CellAutoOverwrite -> True
    ];

errorCell // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*errorText*)
errorText // ClearAll;

errorText[ KeyValuePattern[ "BodyJSON" -> KeyValuePattern[ "error" -> KeyValuePattern[ "message" -> s_String ] ] ] ] :=
    errorText @ s;

errorText[ str_String ] /; StringMatchQ[ str, "The model: `" ~~ __ ~~ "` does not exist" ] :=
    Module[ { model, link, help, message },

        model = StringReplace[ str, "The model: `" ~~ m__ ~~ "` does not exist" :> m ];
        link  = textLink[ "here", "https://platform.openai.com/docs/models/overview" ];
        help  = { " Click ", link, " for information about available models." };

        message = If[ MemberQ[ getModelList[ ], model ],
                      "The specified API key does not have access to the model \"" <> model <> "\".",
                      "The model \"" <> model <> "\" does not exist or the specified API key does not have access to it."
                  ];

        Flatten @ { message, help }
    ];

(*
    Note the subtle difference here where `model` is not followed by a colon.
    This is apparently the best way we can determine the difference between a model that exists but isn't revealed
    to the user and one that actually does not exist. Yes, this is ugly and will eventually be wrong.
*)
errorText[ str_String ] /; StringMatchQ[ str, "The model `" ~~ __ ~~ "` does not exist" ] :=
    Module[ { model, link, help, message },

        model = StringReplace[ str, "The model `" ~~ m__ ~~ "` does not exist" :> m ];
        link  = textLink[ "here", "https://platform.openai.com/docs/models/overview" ];
        help  = { " Click ", link, " for information about available models." };

        message = If[ MemberQ[ getModelList[ ], model ],
                      "The specified API key does not have access to the model \"" <> model <> "\".",
                      "The model \"" <> model <> "\" does not exist."
                  ];

        Flatten @ { message, help }
    ];

errorText[ str_String ] := str;
errorText[ failure_Failure ] := ToString @ failure[ "Message" ];
errorText[ ___ ] := "An unexpected error occurred.";

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*textLink*)
textLink // beginDefinition;

textLink[ url_String ] := textLink[ url, url ];

textLink[ label_, url_String ] := ButtonBox[
    label,
    BaseStyle  -> "Hyperlink",
    ButtonData -> { URL @ url, None },
    ButtonNote -> url
];

textLink // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*errorBoxes*)
errorBoxes // ClearAll;

(* TODO: define error messages for other documented responses *)
errorBoxes[ as: KeyValuePattern[ "StatusCode" -> 429 ] ] :=
    ToBoxes @ messageFailure[ "RateLimitReached", as ];

errorBoxes[ as: KeyValuePattern[ "StatusCode" -> code: Except[ 200 ] ] ] :=
    ToBoxes @ messageFailure[ "UnknownStatusCode", as ];

errorBoxes[ failure_Failure ] :=
    ToBoxes @ failure;

errorBoxes[ as___ ] :=
    ToBoxes @ messageFailure[ "UnknownResponse", as ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
If[ Wolfram`ChatbookInternal`$BuildingMX,
    Null;
];

(* :!CodeAnalysis::EndBlock:: *)

End[ ];
EndPackage[ ];