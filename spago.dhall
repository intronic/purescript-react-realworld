{ name = "purescript-react-realword"
, dependencies =
  [ "aff"
  , "affjax"
  , "argonaut-core"
  , "arrays"
  , "bifunctors"
  , "codec"
  , "codec-argonaut"
  , "console"
  , "control"
  , "datetime"
  , "effect"
  , "either"
  , "exceptions"
  , "foldable-traversable"
  , "foreign-object"
  , "functions"
  , "halogen-subscriptions"
  , "heterogeneous"
  , "http-methods"
  , "integers"
  , "js-timers"
  , "maybe"
  , "media-types"
  , "newtype"
  , "ordered-collections"
  , "parallel"
  , "partial"
  , "prelude"
  , "profunctor"
  , "profunctor-lenses"
  , "react-basic"
  , "react-basic-dom"
  , "react-basic-hooks"
  , "react-halo"
  , "record"
  , "refs"
  , "remotedata"
  , "routing"
  , "routing-duplex"
  , "strings"
  , "transformers"
  , "tuples"
  , "validation"
  , "web-dom"
  , "web-html"
  , "web-router"
  , "web-storage"
  ]
, packages = ./packages.dhall
, sources = [ "src/**/*.purs", "test/**/*.purs" ]
}
