module Test.Kore.Builtin.InternalBytes where

import qualified Data.ByteString.Char8 as BS
import Hedgehog hiding
    ( Concrete
    )
import qualified Hedgehog.Gen as Gen
import qualified Hedgehog.Range as Range
import Test.Tasty

import Data.ByteString
    ( ByteString
    )
import Data.Char
    ( ord
    )
import Data.Text
    ( Text
    )
import qualified Data.Text as T
import GHC.Stack
    ( HasCallStack
    )

import qualified Kore.Builtin.Encoding as E
import qualified Kore.Builtin.InternalBytes as InternalBytes
import Kore.Internal.Pattern
import Kore.Internal.TermLike hiding
    ( bytesSort
    )

import Test.Kore.Builtin.Builtin
import Test.Kore.Builtin.Definition
import qualified Test.Kore.Builtin.Int as Test.Int
import qualified Test.Kore.Builtin.String as Test.String
import Test.SMT

genString :: Gen Text
genString = Gen.text (Range.linear 0 256) Gen.latin1

genString' :: Int -> Gen Text
genString' i = Gen.text (Range.linear 0 i) Gen.latin1

test_update :: [TestTree]
test_update =
    [ testPropertyWithSolver "∀ b v. update b 0 v = v" $ do
        val <- forAll Gen.unicode
        let
            val' = toInteger $ ord val
            bytes = BS.pack [val]
            expect = asPattern bytes
        actual <- evaluateT
            $ mkApplySymbol
                updateBytesSymbol
                [ asInternal bytes
                , Test.Int.asInternal 0
                , Test.Int.asInternal val'
                ]
        (===) expect actual
    , testPropertyWithSolver "∀ b i v (i < 0). update b i v = ⊥" $ do
        str <- forAll genString
        val <- forAll Gen.unicode
        idx <- forAll $ Gen.int (Range.linear (-256) (-1))
        let
            bytes = E.encode8Bit str
            val' = toInteger $ ord val
            expect = bottom
        actual <- evaluateT
            $ mkApplySymbol
                updateBytesSymbol
                [ asInternal bytes
                , Test.Int.asInternal (toInteger idx)
                , Test.Int.asInternal val'
                ]
        (===) expect actual
    , testPropertyWithSolver "∀ b i v (i > length bs). update b i v = ⊥" $ do
        str <- forAll genString
        val <- forAll Gen.unicode
        let
            bytes = E.encode8Bit str
            val' = toInteger $ ord val
            expect = bottom
        actual <- evaluateT
            $ mkApplySymbol
                updateBytesSymbol
                [ asInternal bytes
                , Test.Int.asInternal (toInteger $ BS.length bytes)
                , Test.Int.asInternal val'
                ]
        (===) expect actual
    , testBytes
        "update 'abcd' 0 'x' = 'xbcd'"
        updateBytesSymbol
        [ asInternal "abcd"
        , Test.Int.asInternal 0
        , Test.Int.asInternal (toInteger $ ord 'x')
        ]
        (asPattern "xbcd")
    , testBytes
        "update 'abcd' 3 'x' = 'abcx"
        updateBytesSymbol
        [ asInternal "abcd"
        , Test.Int.asInternal 3
        , Test.Int.asInternal (toInteger $ ord 'x')
        ]
        (asPattern "abcx")
    ]

test_get :: [TestTree]
test_get =
    [ testPropertyWithSolver "∀ b i (i < 0). get b i = ⊥" $ do
        str <- forAll genString
        idx <- forAll $ Gen.int (Range.linear (-256) (-1))
        let
            bytes = E.encode8Bit str
            expect = bottom
        actual <- evaluateT
            $ mkApplySymbol
                getBytesSymbol
                [ asInternal bytes
                , Test.Int.asInternal (toInteger idx)
                ]
        (===) expect actual
    , testPropertyWithSolver "∀ b i (i > len b). get b i = ⊥" $ do
        str <- forAll genString
        let
            bytes = E.encode8Bit str
            expect = bottom
        actual <- evaluateT
            $ mkApplySymbol
                getBytesSymbol
                [ asInternal bytes
                , Test.Int.asInternal (toInteger $ BS.length bytes)
                ]
        (===) expect actual
    , testPropertyWithSolver "∀ i. get empty i = ⊥" $ do
        idx <- forAll $ Gen.int (Range.linear 0 256)
        let
            expect = bottom
        actual <- evaluateT
            $ mkApplySymbol
                getBytesSymbol
                [ asInternal ""
                , Test.Int.asInternal (toInteger idx)
                ]
        (===) expect actual
    , testBytes
        "get 'abcd' 0 = 'a'"
        getBytesSymbol
        [ asInternal "abcd"
        , Test.Int.asInternal 0
        ]
        (Test.Int.asPattern $ toInteger $ ord 'a')
    , testBytes
        "get 'abcd' 3 = 'd'"
        getBytesSymbol
        [ asInternal "abcd"
        , Test.Int.asInternal 3
        ]
        (Test.Int.asPattern $ toInteger $ ord 'd')
    ]

test_substr :: [TestTree]
test_substr =
    [ testPropertyWithSolver "∀ b s e (b >= e). substr b s e = ⊥" $ do
        str <- forAll genString
        begin <- forAll $ Gen.int (Range.linear 0 (T.length str - 1))
        delta <- forAll $ Gen.int (Range.linear 0 10)
        let
            bytes = E.encode8Bit str
            expect = bottom
        actual <- evaluateT
            $ mkApplySymbol
                substrBytesSymbol
                [ asInternal bytes
                , Test.Int.asInternal (toInteger $ begin + delta)
                , Test.Int.asInternal (toInteger begin)
                ]
        (===) expect actual
    , testPropertyWithSolver "∀ b s e (e > length b). substr b s e = ⊥" $ do
        str <- forAll $ genString' 20
        end <- forAll $ Gen.int (Range.linear 21 30)
        let
            bytes = E.encode8Bit str
            expect = bottom
        actual <- evaluateT
            $ mkApplySymbol
                substrBytesSymbol
                [ asInternal bytes
                , Test.Int.asInternal 0
                , Test.Int.asInternal (toInteger end)
                ]
        (===) expect actual
    , testPropertyWithSolver "∀ b s e (b < 0). substr b s e = ⊥" $ do
        str <- forAll genString
        begin <- forAll $ Gen.int (Range.linear (-256) (-1))
        end <- forAll $ Gen.int (Range.linear 0 256)
        let
            bytes = E.encode8Bit str
            expect = bottom
        actual <- evaluateT
            $ mkApplySymbol
                substrBytesSymbol
                [ asInternal bytes
                , Test.Int.asInternal (toInteger begin)
                , Test.Int.asInternal (toInteger end)
                ]
        (===) expect actual
    , testBytes
        "substr 'abcd' 0 1 = 'a'"
        substrBytesSymbol
        [ asInternal "abcd"
        , Test.Int.asInternal 0
        , Test.Int.asInternal 1
        ]
        (asPattern "a")
    , testBytes
        "substr 'abcd' 1 3 = 'bc'"
        substrBytesSymbol
        [ asInternal "abcd"
        , Test.Int.asInternal 1
        , Test.Int.asInternal 3
        ]
        (asPattern "bc")
    , testBytes
        "substr 'abcd' 0 4 = 'abcd'"
        substrBytesSymbol
        [ asInternal "abcd"
        , Test.Int.asInternal 0
        , Test.Int.asInternal 4
        ]
        (asPattern "abcd")
    ]

test_replaceAt :: [TestTree]
test_replaceAt =
    [ testPropertyWithSolver "∀ b i. replaceAt b i '' = n" $ do
        str <- forAll genString
        idx <- forAll $ Gen.int (Range.linear 0 256)
        let
            bytes = E.encode8Bit str
            expect = asPattern bytes
        actual <- evaluateT
            $ mkApplySymbol
                replaceAtBytesSymbol
                [ asInternal bytes
                , Test.Int.asInternal (toInteger idx)
                , asInternal ""
                ]
        (===) expect actual
    , testPropertyWithSolver "∀ b i (b /= ''). replaceAt '' i b = ⊥" $ do
        str <- forAll $ Gen.text (Range.linear 1 256) Gen.alphaNum
        idx <- forAll $ Gen.int (Range.linear 0 256)
        let expect = bottom
        actual <- evaluateT
            $ mkApplySymbol
                replaceAtBytesSymbol
                [ asInternal ""
                , Test.Int.asInternal (toInteger idx)
                , asInternal $ E.encode8Bit str
                ]
        (===) expect actual
    , testPropertyWithSolver
        "∀ b i b' (b' /= '', i >= length b). replaceAt b i b' = ⊥" $ do
        str <- forAll $ genString' 20
        idx <- forAll $ Gen.int (Range.linear 21 256)
        new <- forAll $ Gen.text (Range.linear 1 256) Gen.alphaNum
        let
            bytes = E.encode8Bit str
            bytes' = E.encode8Bit new
            expect = bottom
        actual <- evaluateT
            $ mkApplySymbol
                replaceAtBytesSymbol
                [ asInternal bytes
                , Test.Int.asInternal (toInteger idx)
                , asInternal bytes'
                ]
        (===) expect actual
    , testBytes
        "replaceAt 'abcd' 0 '12' = '12cd'"
        replaceAtBytesSymbol
        [ asInternal "abcd"
        , Test.Int.asInternal 0
        , asInternal "12"
        ]
        (asPattern "12cd")
    , testBytes
        "replaceAt 'abcd' 1 '12' = 'a12d'"
        replaceAtBytesSymbol
        [ asInternal "abcd"
        , Test.Int.asInternal 1
        , asInternal "12"
        ]
        (asPattern "a12d")
    , testBytes
        "replaceAt 'abcd' 3 '12' = 'abc12'"
        replaceAtBytesSymbol
        [ asInternal "abcd"
        , Test.Int.asInternal 3
        , asInternal "12"
        ]
        (asPattern "abc12")
    ]

test_padRight :: [TestTree]
test_padRight =
    [ testPropertyWithSolver "∀ b i v (i >= length b). padRight b i v = b" $ do
        str <- forAll genString
        val <- forAll Gen.alphaNum
        let
            bytes = E.encode8Bit str
            expect = asPattern bytes
        actual <- evaluateT
            $ mkApplySymbol
                padRightBytesSymbol
                [ asInternal bytes
                , Test.Int.asInternal (toInteger $ BS.length bytes)
                , Test.Int.asInternal (toInteger $ ord val)
                ]
        (===) expect actual
    , testBytes
        "padRight 'abcd' 5 'e' = 'abcde"
        padRightBytesSymbol
        [ asInternal "abcd"
        , Test.Int.asInternal 5
        , Test.Int.asInternal (toInteger $ ord 'e')
        ]
        (asPattern "abcde")
    ]

test_padLeft :: [TestTree]
test_padLeft =
    [ testPropertyWithSolver "∀ b i v (i >= length b). padLeft b i v = b" $ do
        str <- forAll genString
        val <- forAll Gen.alphaNum
        let
            bytes = E.encode8Bit str
            expect = asPattern bytes
        actual <- evaluateT
            $ mkApplySymbol
                padLeftBytesSymbol
                [ asInternal bytes
                , Test.Int.asInternal (toInteger $ BS.length bytes)
                , Test.Int.asInternal (toInteger $ ord val)
                ]
        (===) expect actual
    , testBytes
        "padLeft 'abcd' 5 'e' = 'eabcd"
        padLeftBytesSymbol
        [ asInternal "abcd"
        , Test.Int.asInternal 5
        , Test.Int.asInternal (toInteger $ ord 'e')
        ]
        (asPattern "eabcd")
    ]

test_reverse :: [TestTree]
test_reverse =
    [ testPropertyWithSolver "∀ b. reverse (reverse b) = b" $ do
        str <- forAll genString
        let
            bytes = E.encode8Bit str
            expect = asPattern bytes
        actual <- evaluateT
            $ mkApplySymbol
                reverseBytesSymbol
                [ mkApplySymbol
                    reverseBytesSymbol
                    [ asInternal bytes
                    ]
                ]
        (===) expect actual
    , testBytes
        "reverse 'abcd' = 'dcba'"
        reverseBytesSymbol
        [ asInternal "abcd"
        ]
        (asPattern "dcba")
    ]

test_length :: [TestTree]
test_length =
    [ testBytes
        "length 'abcd' = 4"
        lengthBytesSymbol
        [ asInternal "abcd"
        ]
        (Test.Int.asPattern 4)
    , testBytes
        "length '' = 0"
        lengthBytesSymbol
        [ asInternal ""
        ]
        (Test.Int.asPattern 0)
    ]

test_concat :: [TestTree]
test_concat =
    [ testPropertyWithSolver "∀ b. concat b '' = b" $ do
        str <- forAll genString
        let
            bytes = E.encode8Bit str
            expect = asPattern bytes
        actual <- evaluateT
            $ mkApplySymbol
                concatBytesSymbol
                [ asInternal bytes
                , asInternal ""
                ]
        (===) expect actual
    , testPropertyWithSolver "∀ b. concat '' b = b" $ do
        str <- forAll genString
        let
            bytes = E.encode8Bit str
            expect = asPattern bytes
        actual <- evaluateT
            $ mkApplySymbol
                concatBytesSymbol
                [ asInternal ""
                , asInternal bytes
                ]
        (===) expect actual
    , testBytes
        "concat 'abcd' 'efgh' = 'abcdefgh'"
        concatBytesSymbol
        [ asInternal "abcd"
        , asInternal "efgh"
        ]
        (asPattern "abcdefgh")
    ]

test_reverse_length :: TestTree
test_reverse_length =
    testPropertyWithSolver "∀ b. length (reverse b) = length b" $ do
        str <- forAll genString
        let
            bytes = E.encode8Bit str
            expect = Test.Int.asPattern $ toInteger $ BS.length bytes
        actual <- evaluateT
            $ mkApplySymbol
                lengthBytesSymbol
                [ mkApplySymbol
                    reverseBytesSymbol
                    [ asInternal bytes
                    ]
                ]
        (===) expect actual

test_update_get :: TestTree
test_update_get =
    testPropertyWithSolver "∀ b i. update b i (get b i) = b" $ do
        str <- forAll $ Gen.text (Range.linear 1 256) Gen.alphaNum
        idx <- forAll $ Gen.int (Range.linear 0 (T.length str - 1))
        let
            bytes = E.encode8Bit str
            expect = asPattern bytes
        actual <- evaluateT
            $ mkApplySymbol
                updateBytesSymbol
                [ asInternal bytes
                , Test.Int.asInternal $ toInteger idx
                , mkApplySymbol
                    getBytesSymbol
                    [ asInternal bytes
                    , Test.Int.asInternal $ toInteger idx
                    ]
                ]
        (===) expect actual

test_bytes2string_string2bytes :: TestTree
test_bytes2string_string2bytes =
    testPropertyWithSolver "∀ s. bytes2string (string2bytes s) = s" $ do
        str <- forAll genString
        let
            expect = Test.String.asPattern str
        actual <- evaluateT
            $ mkApplySymbol
                bytes2stringBytesSymbol
                [ mkApplySymbol
                    string2bytesBytesSymbol
                    [ Test.String.asInternal str
                    ]
                ]
        (===) expect actual

asInternal :: ByteString -> TermLike Variable
asInternal = InternalBytes.asInternal bytesSort string2bytesBytesSymbol

asPattern :: ByteString -> Pattern Variable
asPattern = InternalBytes.asPattern bytesSort string2bytesBytesSymbol

testBytes
    :: HasCallStack
    => String
    -> Symbol
    -> [TermLike Variable]
    -> Pattern Variable
    -> TestTree
testBytes name = testSymbolWithSolver evaluate name
