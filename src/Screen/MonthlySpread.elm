module Screen.MonthlySpread exposing (Index, Model, Msg(..), dayView, defaultModel, init, subscriptions, update, view)

import Browser.Navigation
import Dict exposing (Dict)
import Html exposing (Html, text)
import Html.Attributes exposing (class, style)
import Html.Events
import Json.Decode as Decode exposing (Decoder)
import Material.Button exposing (buttonConfig, textButton)
import Material.Card exposing (card, cardBlock, cardConfig)
import Material.IconButton exposing (iconButton, iconButtonConfig)
import Material.List exposing (list, listConfig)
import Material.TextField exposing (textField, textFieldConfig)
import Material.TopAppBar as TopAppBar
import Parse
import Route exposing (Route)
import Screen
import Task
import Time.Calendar.Gregorian as Calendar
import Time.Calendar.MonthDay as Calendar
import Time.Calendar.OrdinalDate as Calendar
import Time.Calendar.Week as Calendar
import Type.Bullet as Bullet exposing (Bullet)
import Type.Day as Day exposing (Day)


type alias Model =
    { date : { year : Int, month : Int }
    , bullets : List (Parse.Object Bullet)
    , error : Maybe Parse.Error
    }


defaultModel : { year : Int, month : Int } -> Model
defaultModel date =
    { date = date
    , bullets = []
    , error = Nothing
    }


type Msg msg
    = BulletsResult (Result Parse.Error (List (Parse.Object Bullet)))
    | NewBulletClicked
    | BackClicked
    | BulletClicked (Parse.ObjectId Bullet)


type alias Index =
    Int


init :
    (Msg msg -> msg)
    -> Screen.Config msg
    -> { year : Int, month : Int }
    -> Model
    -> ( Model, Cmd msg )
init lift viewConfig ({ year, month } as date) model =
    ( defaultModel date
    , Parse.send viewConfig.parse
        (lift << BulletsResult)
        (Parse.query Bullet.decode (Parse.emptyQuery "Bullet"))
    )


subscriptions lift model =
    Sub.none


update :
    (Msg msg -> msg)
    -> Screen.Config msg
    -> Msg msg
    -> Model
    -> ( Model, Cmd msg )
update lift viewConfig msg model =
    case msg of
        BulletsResult (Err err) ->
            ( { model | error = Just err }, Cmd.none )

        BulletsResult (Ok bullets) ->
            ( { model | bullets = bullets }, Cmd.none )

        NewBulletClicked ->
            ( model, Browser.Navigation.pushUrl viewConfig.key (Route.toString (Route.EditBullet Nothing)) )

        BackClicked ->
            ( model
            , Browser.Navigation.pushUrl viewConfig.key (Route.toString Route.Start)
            )

        BulletClicked bulletId ->
            ( model
            , Browser.Navigation.pushUrl viewConfig.key
                (Route.toString (Route.EditBullet (Just bulletId)))
            )


view : (Msg msg -> msg) -> Screen.Config msg -> Model -> List (Html msg)
view lift viewConfig model =
    let
        title =
            String.fromInt model.date.year ++ "-" ++ String.fromInt model.date.month
    in
    [ viewConfig.topAppBar
        { title = title
        , menuIcon =
            Just <|
                iconButton
                    { iconButtonConfig
                        | onClick = Just (lift BackClicked)
                        , additionalAttributes = [ TopAppBar.navigationIcon ]
                    }
                    "arrow_back"
        , additionalSections =
            [ TopAppBar.section [ TopAppBar.alignEnd ]
                [ textButton
                    { buttonConfig
                        | onClick = Just (lift NewBulletClicked)
                    }
                    "New bullet"
                ]
            ]
        }
    , Html.div
        [ class "monthly-spread"
        , viewConfig.fixedAdjust
        ]
        [ card
            { cardConfig
                | additionalAttributes = [ class "monthly-spread__wrapper" ]
            }
            { blocks =
                [ cardBlock <|
                    Html.div []
                        [ Html.div
                            [ class "monthly-spread__primary" ]
                            [ Html.div
                                [ class "monthly-spread__title" ]
                                [ text title ]
                            , Html.div
                                [ class "monthly-spread__subtitle" ]
                                [ text "The Monthly Log helps you organize your month. It consists of a calendar and a task list." ]
                            ]
                        , Html.div
                            [ class "monthly-spread__content-wrapper" ]
                            [ Html.ol
                                [ class "monthly-spread__days-wrapper" ]
                                (List.map
                                    (\dayOfMonth ->
                                        dayView lift dayOfMonth model
                                    )
                                    (List.range 1
                                        (Calendar.monthLength
                                            (Calendar.isLeapYear model.date.year)
                                            model.date.month
                                        )
                                    )
                                )
                            , list
                                { listConfig
                                    | additionalAttributes =
                                        [ class "monthly-spread__bullets-wrapper" ]
                                }
                                (List.map
                                    (\bullet ->
                                        Bullet.view
                                            { additionalOptions =
                                                [ class "monthly-spread__bullet"
                                                , Html.Events.onClick
                                                    (lift (BulletClicked bullet.objectId))
                                                ]
                                            }
                                            (Bullet.fromParseObject bullet)
                                    )
                                    model.bullets
                                )
                            ]
                        ]
                ]
            , actions = Nothing
            }
        ]
    ]


dayView lift dayOfMonth model =
    let
        day =
            Calendar.fromGregorian model.date.year
                model.date.month
                dayOfMonth

        dayOfWeek =
            Calendar.dayOfWeek day
    in
    Html.li
        [ class "monthly-spread__day"
        ]
        [ Html.span
            [ class "monthly-spread__day__day-of-month"
            ]
            [ text (String.fromInt dayOfMonth)
            ]
        , Html.span
            [ class "monthly-spread__day__day-of-week"
            ]
            [ text
                (case dayOfWeek of
                    Calendar.Monday ->
                        "M"

                    Calendar.Tuesday ->
                        "T"

                    Calendar.Wednesday ->
                        "W"

                    Calendar.Thursday ->
                        "T"

                    Calendar.Friday ->
                        "F"

                    Calendar.Saturday ->
                        "S"

                    Calendar.Sunday ->
                        "S"
                )
            ]
        ]
