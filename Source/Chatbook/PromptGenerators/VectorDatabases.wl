(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`PromptGenerators`VectorDatabases`" ];
Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"                         ];
Needs[ "Wolfram`Chatbook`Common`"                  ];
Needs[ "Wolfram`Chatbook`PromptGenerators`Common`" ];

HoldComplete[
    System`VectorDatabaseObject,
    System`VectorDatabaseSearch
];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Configuration*)
$vectorDatabases = <|
    "DataRepositoryURIs"     -> <| "Version" -> "1.0.0", "Bias" -> 1.0 |>,
    "DocumentationURIs"      -> <| "Version" -> "1.3.0", "Bias" -> 0.0 |>,
    "FunctionRepositoryURIs" -> <| "Version" -> "1.0.0", "Bias" -> 1.0 |>,
    "WolframAlphaQueries"    -> <| "Version" -> "1.3.0", "Bias" -> 0.0 |>
|>;

$vectorDBNames   = Keys @ $vectorDatabases;
$allowDownload   = True;
$cacheEmbeddings = True;

$embeddingDimension      = 384;
$maxNeighbors            = 50;
$maxEmbeddingDistance    = 150.0;
$embeddingService        = "Local";
$embeddingModel          = "SentenceBERT";
$embeddingAuthentication = Automatic; (* FIXME *)


$conversationVectorSearchPenalty = 1.0;

$relatedQueryCount = 5;
$relatedDocsCount  = 20;
$querySampleCount  = 10;

$relevantFileCount = 3;
$maxExtraFiles     = 20;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Remote Content Locations*)
$baseVectorDatabasesURL = "https://www.wolframcloud.com/obj/wolframai-content/VectorDatabases";

$vectorDBDownloadURLs = AssociationMap[
    URLBuild @ { $baseVectorDatabasesURL, #, $vectorDatabases[ #, "Version" ], # <> ".zip" } &,
    $vectorDBNames
];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Paths*)
$pacletVectorDBDirectory := FileNameJoin @ { $thisPaclet[ "Location" ], "Assets/VectorDatabases" };
$localVectorDBDirectory  := ChatbookFilesDirectory[ "VectorDatabases" ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Argument Patterns*)
$$vectorDatabase = HoldPattern[ _VectorDatabaseObject? System`Private`ValidQ ];

$$dbName        = Alternatives @@ $vectorDBNames;
$$dbNames       = { $$dbName... };
$$dbNameOrNames = $$dbName | $$dbNames;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Cache*)
$vectorDBSearchCache = <| |>;
$embeddingCache      = <| |>;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*InstallVectorDatabases*)
InstallVectorDatabases // beginDefinition;

InstallVectorDatabases[ ] := catchMine @ Enclose[
    Success[
        "VectorDatabasesInstalled",
        <| "Location" -> ConfirmBy[ getVectorDBDirectory[ ], vectorDBDirectoryQ, "Location" ] |>
    ],
    throwInternalFailure
];

InstallVectorDatabases // endExportedDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Vector Database Utilities*)
$vectorDBDirectory := getVectorDBDirectory[ ];

$noSemanticSearch := $noSemanticSearch = ! PacletObjectQ @ Quiet @ PacletInstall[ "SemanticSearch" ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*getVectorDBDirectory*)
getVectorDBDirectory // beginDefinition;

getVectorDBDirectory[ ] := Enclose[
    $vectorDBDirectory = SelectFirst[
        {
            $pacletVectorDBDirectory,
            $localVectorDBDirectory
        },
        vectorDBDirectoryQ,
        (* TODO: need a version of this that prompts the user with a dialog asking them to download *)
        ConfirmBy[ downloadVectorDatabases[ ], vectorDBDirectoryQ, "Downloaded" ]
    ],
    throwInternalFailure
];

getVectorDBDirectory // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*vectorDBDirectoryQ*)
vectorDBDirectoryQ // beginDefinition;
vectorDBDirectoryQ[ dir_? DirectoryQ ] := AllTrue[ $vectorDBNames, vectorDBDirectoryQ0 @ FileNameJoin @ { dir, # } & ];
vectorDBDirectoryQ[ _ ] := False;
vectorDBDirectoryQ // endDefinition;

vectorDBDirectoryQ0 // beginDefinition;

vectorDBDirectoryQ0[ dir_? DirectoryQ ] := Enclose[
    Module[ { name, existsQ, expected, versionFile, expectedVersion },

        name            = ConfirmBy[ FileBaseName @ dir, StringQ, "Name" ];
        existsQ         = FileExistsQ @ FileNameJoin @ { dir, # } &;
        expected        = { name <> ".wxf", "Values.wxf", name <> "-vectors.usearch" };
        versionFile     = FileNameJoin @ { dir, "Version.wl" };
        expectedVersion = ConfirmBy[ $vectorDatabases[ name, "Version" ], StringQ, "ExpectedVersion" ];

        TrueQ[ AllTrue[ expected, existsQ ] && FileExistsQ @ versionFile && Get @ versionFile === expectedVersion ]
    ],
    throwInternalFailure
];

vectorDBDirectoryQ0[ _ ] := False;

vectorDBDirectoryQ0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*downloadVectorDatabases*)
downloadVectorDatabases // beginDefinition;

downloadVectorDatabases[ ] /; ! $allowDownload :=
    Throw[ Missing[ "DownloadDisabled" ], $vdbTag ];

downloadVectorDatabases[ ] :=
    downloadVectorDatabases[ $localVectorDBDirectory, $vectorDBDownloadURLs ];

downloadVectorDatabases[ dir0_, urls0_Association ] := Enclose[
    Module[ { dir, lock, names, urls, sizes, tasks },

        dir = ConfirmBy[ GeneralUtilities`EnsureDirectory @ dir0, DirectoryQ, "Directory" ];
        cleanupLegacyVectorDBFiles @ dir;
        names = Select[ $vectorDBNames, ! DirectoryQ @ FileNameJoin @ { dir, # } & ];
        urls  = KeyTake[ urls0, names ];

        lock  = FileNameJoin @ { dir, "download.lock" };
        sizes = ConfirmMatch[ getDownloadSize /@ Values @ urls, { __? Positive }, "Sizes" ];

        $downloadProgress = AssociationMap[ 0 &, names ];
        $progressText = "Downloading semantic search indices\[Ellipsis]";

        evaluateWithProgress[
            WithLock[
                File @ lock
                ,
                tasks = ConfirmMatch[ KeyValueMap[ downloadVectorDatabase @ dir, urls ], { __TaskObject }, "Download" ];
                ConfirmMatch[ taskWait @ tasks, { (_TaskObject|$Failed).. }, "TaskWait" ];
                $progressText = "Unpacking files\[Ellipsis]";
                ConfirmBy[ unpackVectorDatabases @ dir, DirectoryQ, "Unpacked" ]
                ,
                PersistenceTime -> 180
            ],

            <|
                "Text"             :> $progressText,
                "ElapsedTime"      -> Automatic,
                "RemainingTime"    -> Automatic,
                "ByteCountCurrent" :> Total @ $downloadProgress,
                "ByteCountTotal"   -> Total @ sizes,
                "Progress"         -> Automatic
            |>
        ]
    ] // LogChatTiming[ "DownloadVectorDatabases" ],
    throwInternalFailure
];

downloadVectorDatabases // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*cleanupLegacyVectorDBFiles*)
cleanupLegacyVectorDBFiles // beginDefinition;

cleanupLegacyVectorDBFiles[ dir_String ] := Quiet @ Map[
    DeleteDirectory[ #1, DeleteContents -> True ] &,
    Join[
        Select[ FileNames[ DigitCharacter.. ~~ "." ~~ DigitCharacter.. ~~ "." ~~ DigitCharacter.., dir ], DirectoryQ ],
        Select[ FileNames[ $vectorDBNames, dir ], DirectoryQ[ # ] && ! vectorDBDirectoryQ0[ # ] & ]
    ]
];

cleanupLegacyVectorDBFiles // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*getDownloadSize*)
getDownloadSize // beginDefinition;
getDownloadSize[ url_String ] := getDownloadSize @ CloudObject @ url;
getDownloadSize[ obj: $$cloudObject ] := FileByteCount @ obj;
getDownloadSize // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*unpackVectorDatabases*)
unpackVectorDatabases // beginDefinition;

unpackVectorDatabases[ dir_? DirectoryQ ] :=
    unpackVectorDatabases[ dir, FileNames[ "*.zip", dir ] ] // LogChatTiming[ "UnpackVectorDatabases" ];

unpackVectorDatabases[ dir_, zips: { __String } ] :=
    unpackVectorDatabases[ dir, zips, unpackVectorDatabase /@ zips ];

unpackVectorDatabases[ dir_, zips_, extracted: { { __String }.. } ] :=
    dir;

unpackVectorDatabases // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*unpackVectorDatabase*)
unpackVectorDatabase // beginDefinition;

unpackVectorDatabase[ zip_String? FileExistsQ ] := Enclose[
    Module[ { name, version, root, dir, res, versionFile },
        name = ConfirmBy[ FileBaseName @ zip, StringQ, "Name" ];
        version = ConfirmBy[ $vectorDatabases[ name, "Version" ], StringQ, "Version" ];
        root = ConfirmBy[ DirectoryName @ zip, DirectoryQ, "RootDirectory" ];
        dir = ConfirmBy[ GeneralUtilities`EnsureDirectory @ { root, name }, DirectoryQ, "Directory" ];
        res = ConfirmMatch[ ExtractArchive[ zip, dir, OverwriteTarget -> True ], { __? FileExistsQ }, "Extracted" ];
        versionFile = FileNameJoin @ { dir, "Version.wl" };
        Put[ version, versionFile ];
        ConfirmAssert[ Get @ versionFile === version, "VersionCheck" ];
        DeleteFile @ zip;
        res
    ],
    throwInternalFailure
];

unpackVectorDatabase // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*taskWait*)
taskWait // beginDefinition;
taskWait[ tasks_List ] := CheckAbort[ taskWait /@ tasks, Quiet[ TaskRemove /@ tasks ], PropagateAborts -> True ];
taskWait[ task_TaskObject ] := taskWait[ task, task[ "TaskStatus" ] ];
taskWait[ task_TaskObject, "Removed" ] := task;
taskWait[ task_TaskObject, _ ] := TaskWait @ task;
taskWait // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*downloadVectorDatabase*)
downloadVectorDatabase // beginDefinition;

downloadVectorDatabase[ dir_ ] :=
    downloadVectorDatabase[ dir, ## ] &;

downloadVectorDatabase[ dir_, name_String, url_String ] := Enclose[
    Module[ { file, tmp },

        file = ConfirmBy[ FileNameJoin @ { dir, name<>".zip" }, StringQ, "File" ];
        tmp = file <> ".tmp";
        Quiet[ DeleteFile /@ { file, tmp } ];

        With[ { tmp = tmp, file = file },
            ConfirmMatch[
                URLDownloadSubmit[
                    url,
                    tmp,
                    HandlerFunctions -> <|
                        "TaskProgress" -> setDownloadProgress @ name,
                        "TaskFinished" -> (RenameFile[ tmp, file ] &)
                    |>,
                    HandlerFunctionsKeys -> { "ByteCountDownloaded" }
                ],
                _TaskObject,
                "Task"
            ]
        ]
    ] // LogChatTiming[ { "DownloadVectorDatabase", name } ],
    throwInternalFailure
];

downloadVectorDatabase // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*setDownloadProgress*)
setDownloadProgress // beginDefinition;
setDownloadProgress[ name_String ] := setDownloadProgress[ name, ## ] &;
setDownloadProgress[ name_, KeyValuePattern[ "ByteCountDownloaded" -> b_? Positive ] ] := $downloadProgress[ name ] = b;
setDownloadProgress // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*inVectorDBDirectory*)
inVectorDBDirectory // beginDefinition;
inVectorDBDirectory // Attributes = { HoldFirst };
inVectorDBDirectory[ eval_ ] := WithCleanup[ SetDirectory @ $vectorDBDirectory, eval, ResetDirectory[ ] ];
inVectorDBDirectory // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*initializeVectorDatabases*)
initializeVectorDatabases // beginDefinition;
initializeVectorDatabases[ ] := Block[ { $allowDownload = False }, Catch[ getVectorDB /@ $vectorDBNames, $vdbTag ] ];
initializeVectorDatabases // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*getVectorDB*)
getVectorDB // beginDefinition;

getVectorDB[ name_String ] := Enclose[
    getVectorDB[ name ] = ConfirmMatch[
        Association @ loadVectorDB @ name,
        KeyValuePattern @ { "Values" -> { ___String }, "VectorDatabaseObject" -> $$vectorDatabase },
        "VectorDB"
    ],
    throwInternalFailure
];

getVectorDB // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*loadVectorDB*)
loadVectorDB // beginDefinition;

loadVectorDB[ name_String ] := Enclose[
    Module[ { values, vectorDB, dims },

        values   = ConfirmMatch[ loadVectorDBValues @ name, { ___String }, "Values" ];
        vectorDB = ConfirmMatch[ loadVectorDatabase @ name, $$vectorDatabase, "VectorDatabaseObject" ];
        dims     = ConfirmMatch[ inVectorDBDirectory @ vectorDB[ "Dimensions" ], { _Integer, _Integer }, "Dimensions" ];

        ConfirmAssert[ Length @ values === First @ dims, "LengthCheck" ];

        <| "Values" -> values, "VectorDatabaseObject" -> vectorDB |>
    ],
    throwInternalFailure
];

loadVectorDB // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*loadVectorDatabase*)
loadVectorDatabase // beginDefinition;

loadVectorDatabase[ name_String ] := Enclose[
    inVectorDBDirectory @ Module[ { dir, file },
        dir = ConfirmBy[ name, DirectoryQ, "Directory" ];
        file = ConfirmBy[ File @ FileNameJoin @ { dir, name<>".wxf" }, FileExistsQ, "File" ];
        ConfirmMatch[ VectorDatabaseObject @ file, $$vectorDatabase, "Database" ]
    ],
    throwInternalFailure
];

loadVectorDatabase // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*loadVectorDBValues*)
loadVectorDBValues // beginDefinition;

loadVectorDBValues[ name_String ] := Enclose[
    Module[ { root, dir, file },
        root = ConfirmBy[ $vectorDBDirectory, DirectoryQ, "RootDirectory" ];
        dir = ConfirmBy[ FileNameJoin @ { root, name }, DirectoryQ, "Directory" ];
        file = ConfirmBy[ FileNameJoin @ { dir, "Values.wxf" }, FileExistsQ, "File" ];
        loadVectorDBValues[ name ] = ConfirmMatch[ Developer`ReadWXFFile @ file, { __String }, "Read" ]
    ],
    throwInternalFailure
];

loadVectorDBValues // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*vectorDBSearch*)
vectorDBSearch // beginDefinition;


(* Default arguments: *)
vectorDBSearch[ db: $$dbNameOrNames, prompt_String ] :=
    vectorDBSearch[ db, prompt, All ];

vectorDBSearch[ db: $$dbNameOrNames, All ] :=
    vectorDBSearch[ db, All, "Values" ];


(* Shortcuts: *)
vectorDBSearch[ $$dbNameOrNames, "", All ] := <|
    "EmbeddingVector" -> None,
    "SearchData"      -> Missing[ "NoInput" ],
    "Values"          -> { }
|>;

vectorDBSearch[ $$dbNameOrNames, "", "Results"|"Values" ] :=
    { };

vectorDBSearch[ { }, prompt_, prop_ ] :=
    { };


(* Cached results: *)
vectorDBSearch[ dbName: $$dbName, prompt_String, All ] :=
    With[ { result = $vectorDBSearchCache[ dbName, prompt ] },
        result /; AssociationQ @ result
    ];


(* Main definition for string prompt: *)
vectorDBSearch[ dbName: $$dbName, prompt_String, All ] := Enclose[
    Module[ { vectorDBInfo, vectorDB, allValues, embeddingVector, close, indices, distances, values, data, result },

        vectorDBInfo    = ConfirmBy[ getVectorDB @ dbName, AssociationQ, "VectorDBInfo" ];
        vectorDB        = ConfirmMatch[ vectorDBInfo[ "VectorDatabaseObject" ], $$vectorDatabase, "VectorDatabase" ];
        allValues       = ConfirmBy[ vectorDBInfo[ "Values" ], ListQ, "Values" ];
        embeddingVector = ConfirmMatch[ getEmbedding @ prompt, _NumericArray, "EmbeddingVector" ];

        close = ConfirmMatch[
            inVectorDBDirectory @ VectorDatabaseSearch[
                vectorDB,
                embeddingVector,
                { "Index", "Distance" },
                MaxItems -> $maxNeighbors
            ] // LogChatTiming[ "VectorDatabaseSearch" ],
            { ___Association },
            "PositionsAndDistances"
        ];

        indices   = ConfirmMatch[ close[[ All, "Index"    ]], { ___Integer }, "Indices"   ];
        distances = ConfirmMatch[ close[[ All, "Distance" ]], { ___Real    }, "Distances" ];

        values    = ConfirmBy[ allValues[[ indices ]], ListQ, "Values" ];

        ConfirmAssert[ Length @ indices === Length @ distances === Length @ values, "LengthCheck" ];

        data = MapApply[
            <| "Value" -> #1, "Index" -> #2, "Distance" -> #3, "Source" -> dbName |> &,
            Transpose @ { values, indices, distances }
        ];

        result = <| "Values" -> DeleteDuplicates @ values, "Results" -> data, "EmbeddingVector" -> embeddingVector |>;

        (* Cache and verify: *)
        cacheVectorDBResult[ dbName, prompt, result ];
        ConfirmAssert[ $vectorDBSearchCache[ dbName, prompt ] === result, "CacheCheck" ];

        result
    ],
    throwInternalFailure
];


(* Main definition for a list of messages: *)
vectorDBSearch[ dbName: $$dbName, messages0: { __Association }, prop: "Values"|"Results" ] := Enclose[
    Catch @ Module[
        {
            messages,
            conversationString, lastMessageString, selectionString,
            conversationResults, lastMessageResults, selectionResults,
            combined, n, merged
        },

        (* TODO: asynchronously pre-cache embeddings for each type *)

        messages = DeleteCases[
            ConfirmMatch[ insertContextPrompt @ messages0, { __Association }, "Messages" ],
            KeyValuePattern[ "Content" -> "" | { } ]
        ];

        If[ messages === { }, Throw @ { } ];

        conversationString = ConfirmBy[ getSmallContextString @ messages, StringQ, "ConversationString" ];

        lastMessageString = ConfirmBy[
            getSmallContextString[ { Last @ messages }, "IncludeSystemMessage" -> True ],
            StringQ,
            "LastMessageString"
        ];

        selectionString = If[ StringQ @ $selectionPrompt, $selectionPrompt, None ];

        If[ conversationString === "" || lastMessageString === "", Throw @ { } ];

        getEmbeddings @ Select[ { conversationString, lastMessageString, selectionString }, StringQ ];

        conversationResults = ConfirmMatch[
            MapAt[
                # + $conversationVectorSearchPenalty &,
                vectorDBSearch[ dbName, conversationString, "Results" ],
                { All, "Distance" }
            ],
            { KeyValuePattern[ { "Distance" -> _Real, "Value" -> _ } ]... },
            "ConversationResults"
        ];

        lastMessageResults =
            If[ lastMessageString === conversationString,
                { },
                ConfirmMatch[
                    vectorDBSearch[ dbName, lastMessageString, "Results" ],
                    { KeyValuePattern[ { "Distance" -> _Real, "Value" -> _ } ]... },
                    "LastMessageResults"
                ]
            ];

        selectionResults =
            If[ StringQ @ selectionString,
                ConfirmMatch[
                    vectorDBSearch[ dbName, selectionString, "Results" ],
                    { KeyValuePattern[ { "Distance" -> _Real, "Value" -> _ } ]... },
                    "SelectionResults"
                ],
                { }
            ];

        combined = SortBy[ Join[ conversationResults, lastMessageResults, selectionResults ], Lookup[ "Distance" ] ];

        n = Ceiling[ $maxNeighbors / 10 ];
        merged = Take[
            DeleteDuplicates @ Join[
                Take[ conversationResults, UpTo[ n ] ],
                Take[ lastMessageResults , UpTo[ n ] ],
                Take[ selectionResults   , UpTo[ n ] ],
                combined
            ],
            UpTo[ $maxNeighbors ]
        ];

        If[ prop === "Results",
            merged,
            DeleteDuplicates[ Lookup[ "Value" ] /@ merged ]
        ]
    ],
    throwInternalFailure
];


(* Properties: *)
vectorDBSearch[ db_, prompt_String, "EmbeddingVector" ] := Enclose[
    ConfirmMatch[ getEmbedding @ prompt, _NumericArray, "EmbeddingVector" ],
    throwInternalFailure
];

vectorDBSearch[ dbName: $$dbName, prompt_String, key_String ] := Enclose[
    Lookup[ ConfirmBy[ vectorDBSearch[ dbName, prompt, All ], AssociationQ, "Result" ], key ],
    throwInternalFailure
];

vectorDBSearch[ dbName: $$dbName, prompt_String, keys: { ___String } ] := Enclose[
    KeyTake[ ConfirmBy[ vectorDBSearch[ dbName, prompt, All ], AssociationQ, "Result" ], keys ],
    throwInternalFailure
];

vectorDBSearch[ dbName: $$dbName, prompts: { ___String }, prop_ ] :=
    AssociationMap[ vectorDBSearch[ dbName, #, prop ] &, prompts ];


(* Full list of possible values: *)
vectorDBSearch[ dbName: $$dbName, All, "Values" ] := Enclose[
    Module[ { vectorDBInfo },
        vectorDBInfo = ConfirmBy[ getVectorDB @ dbName, AssociationQ, "VectorDB" ];
        ConfirmBy[ vectorDBInfo[ "Values" ], ListQ, "Values" ]
    ],
    throwInternalFailure
];

vectorDBSearch[ names: $$dbNames, All, "Values" ] :=
    Flatten[ vectorDBSearch[ #, All, "Values" ] & /@ names ];


(* Combine results from multiple vector databases: *)
vectorDBSearch[ names: $$dbNames, prompt_, prop: "Values"|"Results" ] := Enclose[
    Catch @ Module[ { results, sorted },

        results = ConfirmMatch[
            applyBias[ #, vectorDBSearch[ #, prompt, "Results" ] ] & /@ names,
            { { KeyValuePattern[ "Distance" -> $$size ].. }... },
            "Results"
        ];

        sorted = SortBy[ Flatten @ results, #Distance & ];

        If[ prop === "Results",
            sorted,
            ConfirmMatch[
                DeleteDuplicates @ Lookup[ sorted, "Value" ],
                { __String },
                "Values"
            ]
        ]
    ],
    throwInternalFailure
];

vectorDBSearch[ names: $$dbNames, prompt_, All ] :=
    Merge[ vectorDBSearch[ #, prompt, All ] & /@ names, Flatten ];

vectorDBSearch[ All, prompt_ ] :=
    vectorDBSearch[ $vectorDBNames, prompt ];

vectorDBSearch[ All, prompt_, prop_ ] :=
    vectorDBSearch[ $vectorDBNames, prompt, prop ];


vectorDBSearch // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*applyBias*)
applyBias // beginDefinition;
applyBias[ name_String, results_ ] := applyBias[ $vectorDatabases[ name, "Bias" ], results ];
applyBias[ None | _Missing | 0 | 0.0, results_ ] := results;
applyBias[ bias_, results_List ] := (applyBias[ bias, #1 ] &) /@ results;
applyBias[ bias: $$size, as: KeyValuePattern[ "Distance" -> d: $$size ] ] := <| as, "Distance" -> d + bias |>;
applyBias // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*insertContextPrompt*)
insertContextPrompt // beginDefinition;

insertContextPrompt[ messages_ ] :=
    insertContextPrompt[ messages, $contextPrompt, $selectionPrompt ];

insertContextPrompt[ { before___, last_Association }, context_String, selection_String ] := {
    before,
    <| "Role" -> "User"  , "Content" -> context |>,
    <| "Role" -> "System", "Content" -> "User's currently selected text: \""<>selection<>"\"" |>,
    last
};

insertContextPrompt[ { before___, last_Association }, context_String, _ ] := {
    before,
    <| "Role" -> "User", "Content" -> context |>,
    last
};

insertContextPrompt[ messages_List, _, _ ] :=
    messages;

insertContextPrompt // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*cacheVectorDBResult*)
cacheVectorDBResult // beginDefinition;

cacheVectorDBResult[ dbName: $$dbName, prompt_String, data_Association ] := (
    If[ ! AssociationQ @ $vectorDBSearchCache, $vectorDBSearchCache = <| |> ];
    If[ ! AssociationQ @ $vectorDBSearchCache[ dbName ], $vectorDBSearchCache[ dbName ] = <| |> ];
    $vectorDBSearchCache[ dbName, prompt ] = data
);

cacheVectorDBResult // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Embeddings*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*getEmbedding*)
getEmbedding // beginDefinition;
getEmbedding // Options = { "CacheEmbeddings" -> $cacheEmbeddings };

getEmbedding[ string_String, opts: OptionsPattern[ ] ] :=
    With[ { embedding = $embeddingCache[ string ] },
        embedding /; NumericArrayQ @ embedding
    ];

getEmbedding[ string_String, opts: OptionsPattern[ ] ] := Enclose[
    First @ ConfirmMatch[ getEmbeddings[ { string }, opts ], { _NumericArray }, "Embedding" ],
    throwInternalFailure
];

getEmbedding // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*getEmbeddings*)
getEmbeddings // beginDefinition;
getEmbeddings // Options = { "CacheEmbeddings" -> $cacheEmbeddings };

getEmbeddings[ { }, opts: OptionsPattern[ ] ] := { };

getEmbeddings[ strings: { __String }, opts: OptionsPattern[ ] ] :=
    If[ TrueQ @ OptionValue[ "CacheEmbeddings" ],
        getEmbeddings0 @ strings,
        Block[ { $cacheEmbeddings = False }, getAndCacheEmbeddings @ strings ]
    ] // LogChatTiming[ "GetEmbeddings" ];

getEmbeddings // endDefinition;


getEmbeddings0 // beginDefinition;

getEmbeddings0[ strings: { __String } ] := Enclose[
    Module[ { notCached },
        notCached = Select[ strings, ! KeyExistsQ[ $embeddingCache, # ] & ];
        ConfirmMatch[ getAndCacheEmbeddings @ notCached, { ___NumericArray }, "CacheEmbeddings" ];
        ConfirmMatch[ Lookup[ $embeddingCache, strings ], { __NumericArray }, "Result" ]
    ],
    throwInternalFailure
];

getEmbeddings0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*getAndCacheEmbeddings*)
getAndCacheEmbeddings // beginDefinition;

getAndCacheEmbeddings[ { } ] :=
    { };

getAndCacheEmbeddings[ strings: { __String } ] /; $embeddingModel === "SentenceBERT" := Enclose[
    Module[ { vectors },
        vectors = ConfirmBy[
            If[ AllTrue[ strings, StringMatchQ[ WhitespaceCharacter... ] ],
                Developer`ToPackedArray @ Rest @ sentenceBERTEmbedding @ Prepend[ strings, "hello" ],
                Developer`ToPackedArray @ sentenceBERTEmbedding @ strings
            ],
            Developer`PackedArrayQ,
            "PackedArray"
        ];

        ConfirmAssert[ Length @ strings === Length @ vectors, "LengthCheck" ];

        MapThread[ cacheEmbedding, { strings, vectors } ]
    ],
    throwInternalFailure
];

getAndCacheEmbeddings[ strings: { __String } ] := Enclose[
    Module[ { resp, vectors },
        resp = ConfirmBy[
            setServiceCaller @ ServiceExecute[
                $embeddingService,
                "RawEmbedding",
                { "input" -> strings, "model" -> $embeddingModel },
                Authentication -> $embeddingAuthentication
            ],
            AssociationQ,
            "EmbeddingResponse"
        ];

        vectors = ConfirmBy[
            Developer`ToPackedArray @ resp[[ "data", All, "embedding" ]],
            Developer`PackedArrayQ,
            "PackedArray"
        ];

        ConfirmAssert[ Length @ strings === Length @ vectors, "LengthCheck" ];

        MapThread[ cacheEmbedding, { strings, vectors } ]
    ],
    throwInternalFailure
];

getAndCacheEmbeddings // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*cacheEmbedding*)
cacheEmbedding // beginDefinition;
cacheEmbedding[ key_String, vector_ ] /; ! $cacheEmbeddings := toTinyVector @ vector;
cacheEmbedding[ key_String, vector_ ] := $embeddingCache[ key ] = toTinyVector @ vector;
cacheEmbedding // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*sentenceBERTEmbedding*)
sentenceBERTEmbedding := getSentenceBERTEmbeddingFunction[ ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*getSentenceBERTEmbeddingFunction*)
getSentenceBERTEmbeddingFunction // beginDefinition;

getSentenceBERTEmbeddingFunction[ ] := Enclose[
    Module[ { name },

        Needs[ "SemanticSearch`" -> None ];

        name = ConfirmBy[
            SelectFirst[
                {
                    "SemanticSearch`SentenceBERTEmbedding",
                    "SemanticSearch`SemanticSearch`Private`SentenceBERTEmbedding"
                },
                NameQ @ # && ToExpression[ #, InputForm, System`Private`HasAnyEvaluationsQ ] &
            ],
            StringQ,
            "SymbolName"
        ];

        getSentenceBERTEmbeddingFunction[ ] = Symbol @ name
    ],
    throwInternalFailure
];

getSentenceBERTEmbeddingFunction // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*toTinyVector*)
toTinyVector // beginDefinition;
toTinyVector[ v_ ] := NumericArray[ 127.5 * Normalize @ v[[ 1;;$embeddingDimension ]] - 0.5, "Real16" ];
toTinyVector // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
addToMXInitialization[
    Null
];

End[ ];
EndPackage[ ];
