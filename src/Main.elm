module Main exposing (main)

import Browser
import Browser.Navigation
import Dict exposing (Dict)
import Html exposing (Html, text)
import Html.Attributes exposing (class, style)
import Html.Events
import Json.Decode as Decode exposing (Value)
import Material.Button exposing (buttonConfig, textButton)
import Material.Drawer exposing (drawerConfig, drawerScrim, modalDrawer)
import Material.IconButton exposing (iconButton, iconButtonConfig)
import Material.List exposing (list, listConfig, listItem, listItemConfig, listItemGraphic)
import Material.TopAppBar as TopAppBar exposing (topAppBar, topAppBarConfig)
import Parse
import Parse.Private.ObjectId as ObjectId
import ParseConfig exposing (parseConfig)
import Ports
import Route exposing (Route)
import Screen
import Screen.DailySpread
import Screen.EditBullet
import Screen.MonthlySpread
import Screen.Start
import Task exposing (Task)
import Time
import Time.Calendar.Days as Calendar
import Time.Calendar.Gregorian as Calendar
import Time.Format.Locale as Calendar
import Type.Bullet as Bullet exposing (Bullet)
import Url exposing (Url)


type alias Model =
    { key : Browser.Navigation.Key
    , url : Route
    , editBullet : Maybe Screen.EditBullet.Model
    , start : Screen.Start.Model
    , dailySpread : Screen.DailySpread.Model
    , monthlySpread : Screen.MonthlySpread.Model
    , today : Calendar.Day
    , now : Time.Posix
    , error : Maybe Parse.Error
    , timeZone : Time.Zone
    , drawerOpen : Bool
    }


defaultModel : Browser.Navigation.Key -> Model
defaultModel key =
    { url = Route.Start
    , start = Screen.Start.defaultModel
    , editBullet = Nothing
    , dailySpread = Screen.DailySpread.defaultModel { year = 1970, month = 1, dayOfMonth = 1 }
    , monthlySpread = Screen.MonthlySpread.defaultModel { year = 1970, month = 1 }
    , today = Calendar.fromGregorian 1970 1 1
    , now = Time.millisToPosix 0
    , error = Nothing
    , timeZone = Time.utc
    , key = key
    , drawerOpen = False
    }


type Msg
    = NoOp
    | TodayChanged (Maybe Calendar.Day)
    | NowChanged (Maybe Time.Posix)
    | BackClicked
    | EditBulletMsg (Screen.EditBullet.Msg Msg)
    | DailySpreadMsg (Screen.DailySpread.Msg Msg)
    | StartMsg (Screen.Start.Msg Msg)
    | MonthlySpreadMsg (Screen.MonthlySpread.Msg Msg)
    | TodayClicked
    | ThisMonthClicked
    | UrlRequested Browser.UrlRequest
    | UrlChanged Url
    | StartClicked
    | DrawerClosed
    | OpenDrawerClicked


type alias Flags =
    { today : String
    , now : String
    }


main : Program Flags Model Msg
main =
    Browser.application
        { init = init
        , subscriptions = subscriptions
        , update = update
        , view = view
        , onUrlRequest = UrlRequested
        , onUrlChange = UrlChanged
        }


init : Flags -> Url -> Browser.Navigation.Key -> ( Model, Cmd Msg )
init flags url_ key =
    let
        url =
            Route.fromUrl url_

        screenConfig =
            makeScreenConfig model

        model =
            defaultModel key
                |> (\model_ ->
                        { model_
                            | today =
                                Ports.readDayUnsafe flags.today
                                    |> Maybe.withDefault model_.today
                            , now =
                                Ports.readDateUnsafe flags.now
                                    |> Maybe.withDefault model_.now
                            , url = url
                        }
                   )
    in
    ( model, Cmd.none )
        |> andThenInitScreen screenConfig url


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch
        [ Ports.today TodayChanged
        , Ports.now NowChanged
        , Screen.DailySpread.subscriptions DailySpreadMsg model.dailySpread
        , Screen.MonthlySpread.subscriptions MonthlySpreadMsg model.monthlySpread
        , Screen.Start.subscriptions StartMsg model.start
        ]


andThenInitScreen : Screen.Config Msg -> Route -> ( Model, Cmd Msg ) -> ( Model, Cmd Msg )
andThenInitScreen screenConfig url ( model, cmd ) =
    (case url of
        Route.Start ->
            Screen.Start.init StartMsg screenConfig model.start
                |> Tuple.mapFirst (\start -> { model | start = start })

        Route.MonthlySpread date ->
            Screen.MonthlySpread.init MonthlySpreadMsg
                screenConfig
                date
                model.monthlySpread
                |> Tuple.mapFirst
                    (\monthlySpread ->
                        { model | monthlySpread = monthlySpread }
                    )

        Route.DailySpread date ->
            Screen.DailySpread.init
                DailySpreadMsg
                screenConfig
                date
                model.dailySpread
                |> Tuple.mapFirst
                    (\dailySpread ->
                        { model | dailySpread = dailySpread }
                    )

        Route.EditBullet bulletId ->
            Screen.EditBullet.init EditBulletMsg
                screenConfig
                -- TODO:
                Route.Start
                bulletId
                model.editBullet
                |> Tuple.mapFirst
                    (\editBullet ->
                        { model | editBullet = Just editBullet }
                    )

        _ ->
            ( model, Cmd.none )
    )
        |> Tuple.mapSecond
            (\otherCmd ->
                Cmd.batch [ cmd, otherCmd ]
            )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    let
        screenConfig =
            makeScreenConfig model
    in
    case msg of
        NoOp ->
            ( model, Cmd.none )

        MonthlySpreadMsg msg_ ->
            model.monthlySpread
                |> Screen.MonthlySpread.update MonthlySpreadMsg screenConfig msg_
                |> Tuple.mapFirst
                    (\monthlySpread -> { model | monthlySpread = monthlySpread })

        DailySpreadMsg msg_ ->
            model.dailySpread
                |> Screen.DailySpread.update DailySpreadMsg screenConfig msg_
                |> Tuple.mapFirst
                    (\dailySpread -> { model | dailySpread = dailySpread })

        StartMsg msg_ ->
            model.start
                |> Screen.Start.update StartMsg screenConfig msg_
                |> Tuple.mapFirst
                    (\start -> { model | start = start })

        EditBulletMsg msg_ ->
            model.editBullet
                |> Maybe.map (Screen.EditBullet.update EditBulletMsg screenConfig msg_)
                |> Maybe.map
                    (Tuple.mapFirst
                        (\editBullet -> { model | editBullet = Just editBullet })
                    )
                |> Maybe.withDefault ( model, Cmd.none )

        TodayChanged Nothing ->
            ( model, Cmd.none )

        TodayChanged (Just today) ->
            ( { model | today = today }, Cmd.none )

        NowChanged Nothing ->
            ( model, Cmd.none )

        NowChanged (Just now) ->
            ( { model | now = now }, Cmd.none )

        BackClicked ->
            ( model, Browser.Navigation.pushUrl model.key (Route.toString Route.Start) )

        TodayClicked ->
            let
                ( year, month, dayOfMonth ) =
                    Calendar.toGregorian model.today
            in
            ( model
            , Browser.Navigation.pushUrl model.key
                (Route.toString
                    (Route.DailySpread
                        { year = year
                        , month = month
                        , dayOfMonth = dayOfMonth
                        }
                    )
                )
            )

        ThisMonthClicked ->
            let
                ( year, month, _ ) =
                    Calendar.toGregorian model.today
            in
            ( model
            , Browser.Navigation.pushUrl model.key
                (Route.toString (Route.MonthlySpread { year = year, month = month }))
            )

        UrlRequested (Browser.Internal url) ->
            ( model
            , Browser.Navigation.pushUrl model.key (Route.toString (Route.fromUrl url))
            )

        UrlRequested (Browser.External url) ->
            ( model, Browser.Navigation.load url )

        UrlChanged url ->
            ( { model | url = Route.fromUrl url }, Cmd.none )
                |> andThenInitScreen screenConfig (Route.fromUrl url)

        StartClicked ->
            ( model
            , Browser.Navigation.pushUrl model.key (Route.toString Route.Start)
            )

        DrawerClosed ->
            ( { model | drawerOpen = False }, Cmd.none )

        OpenDrawerClicked ->
            ( { model | drawerOpen = True }, Cmd.none )


makeScreenConfig : Model -> Screen.Config Msg
makeScreenConfig model =
    { topAppBar =
        \config ->
            topAppBar { topAppBarConfig | fixed = True }
                [ TopAppBar.row []
                    (List.concat
                        [ [ TopAppBar.section [ TopAppBar.alignStart ]
                                [ config.menuIcon
                                    |> Maybe.withDefault
                                        (iconButton
                                            { iconButtonConfig
                                                | onClick = Just OpenDrawerClicked
                                                , additionalAttributes =
                                                    [ TopAppBar.navigationIcon ]
                                            }
                                            "menu"
                                        )
                                , Html.h1 [ TopAppBar.title ] [ text config.title ]
                                ]
                          ]
                        , [ TopAppBar.section [ TopAppBar.alignStart ]
                                [ textButton
                                    { buttonConfig
                                        | onClick = Just ThisMonthClicked
                                    }
                                    "Month"
                                , textButton
                                    { buttonConfig
                                        | onClick = Just TodayClicked
                                    }
                                    "Today"
                                ]
                          ]
                        , config.additionalSections
                        ]
                    )
                ]
    , fixedAdjust = TopAppBar.fixedAdjust
    , today = model.today
    , now = model.now
    , parse = parseConfig
    , key = model.key
    , timeZone = model.timeZone
    }


view model =
    let
        screenConfig =
            makeScreenConfig model
    in
    { title = "Bujo"
    , body =
        [ Html.div [ class "main" ]
            (drawer model ++ content screenConfig model)
        ]
    }


content screenConfig model =
    [ Html.div [ class "main__content" ]
        (case model.url of
            Route.Start ->
                viewStart screenConfig model

            Route.MonthlySpread objectId ->
                viewMonthlySpread screenConfig model

            Route.DailySpread objectId ->
                viewDailySpread screenConfig model

            Route.NotFound urlString ->
                viewNotFound screenConfig urlString model

            Route.EditBullet _ ->
                viewEditBullet screenConfig model
        )
    ]


drawer model =
    [ modalDrawer
        { drawerConfig
            | open = model.drawerOpen
            , onClose = Just DrawerClosed
        }
        [ list listConfig
            (List.map
                (\{ label, activated, onClick } ->
                    listItem
                        { listItemConfig
                            | activated = activated
                            , onClick = Just onClick
                        }
                        [ text label ]
                )
                [ { label = "Start"
                  , activated = model.url == Route.Start
                  , onClick = StartClicked
                  }
                , { label = "Today"
                  , activated = False
                  , onClick = TodayClicked
                  }
                , { label = "This month"
                  , activated = False
                  , onClick = ThisMonthClicked
                  }
                ]
            )
        ]
    , drawerScrim [] []
    ]


viewMonthlySpread : Screen.Config Msg -> Model -> List (Html Msg)
viewMonthlySpread screenConfig model =
    Screen.MonthlySpread.view MonthlySpreadMsg screenConfig model.monthlySpread


viewDailySpread : Screen.Config Msg -> Model -> List (Html Msg)
viewDailySpread screenConfig model =
    Screen.DailySpread.view DailySpreadMsg screenConfig model.dailySpread


viewNotFound : Screen.Config Msg -> String -> Model -> List (Html Msg)
viewNotFound screenConfig urlString model =
    [ Html.div [ class "not-found" ]
        [ text ("URL not found: " ++ urlString) ]
    ]


viewStart : Screen.Config Msg -> Model -> List (Html Msg)
viewStart screenConfig model =
    Screen.Start.view StartMsg screenConfig model.start


viewEditBullet : Screen.Config Msg -> Model -> List (Html Msg)
viewEditBullet screenConfig model =
    model.editBullet
        |> Maybe.map (Screen.EditBullet.view EditBulletMsg screenConfig)
        |> Maybe.withDefault []
