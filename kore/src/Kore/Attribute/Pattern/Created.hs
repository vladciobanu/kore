{- |
Copyright   : (c) Runtime Verification, 2019
License     : NCSA

 -}

module Kore.Attribute.Pattern.Created
    ( Created (..)
    , hasKnownCreator
    ) where

import Prelude.Kore

import Control.DeepSeq
import Data.Hashable
    ( Hashable (hashWithSalt)
    )
import Data.Text.Prettyprint.Doc
    ( Pretty
    )
import qualified Data.Text.Prettyprint.Doc as Pretty
import qualified Generics.SOP as SOP
import GHC.Generics
import GHC.Stack
    ( SrcLoc (..)
    )
import qualified GHC.Stack as GHC

import Kore.Attribute.Synthetic
import Kore.Debug

-- | 'Created' is used for debugging patterns, specifically for finding out
-- where a pattern was created. This is a field in the attributes of a pattern,
-- and it will default to 'Nothing'. This field is populated via the smart
-- constructors in 'Kore.Internal.TermLike'.
newtype Created = Created { getCreated :: Maybe GHC.CallStack }
    deriving (Generic, Show)

hasKnownCreator :: Created -> Bool
hasKnownCreator = isJust . getCallStackHead

instance Eq Created where
    (==) _ _ = True

instance SOP.Generic Created

instance SOP.HasDatatypeInfo Created

instance NFData Created

instance Hashable Created where
    hashWithSalt _ _ = 0

instance Debug Created

instance Diff Created where
    diffPrec = diffPrecIgnore

instance Pretty Created where
    pretty =
        maybe "" go . getCallStackHead
      where
        go (name, srcLoc) =
            Pretty.hsep ["/* Created:", qualifiedName, "*/"]
          where
            qualifiedName =
                    Pretty.pretty srcLocModule
                <>  Pretty.dot
                <>  Pretty.pretty name
            SrcLoc { srcLocModule } = srcLoc

instance Functor pat => Synthetic Created pat where
    synthetic = const (Created Nothing)

getCallStackHead :: Created -> Maybe (String, SrcLoc)
getCallStackHead Created { getCreated } =
    GHC.getCallStack <$> getCreated >>= headMay
