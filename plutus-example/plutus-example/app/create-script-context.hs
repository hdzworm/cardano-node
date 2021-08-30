{-# LANGUAGE TypeApplications #-}

import           Prelude

import           Cardano.Api

import           Control.Monad.Trans.Except (runExceptT)
import qualified Data.ByteString.Lazy as LB
import           Data.Foldable
import           Data.Word
import           Options.Applicative
import qualified Options.Applicative as Opt

import           Cardano.PlutusExample.ScriptContextChecker

main :: IO ()
main = runScriptContextCmd =<< customExecParser pref opts

pref :: ParserPrefs
pref = Opt.prefs showHelpOnEmpty

opts :: ParserInfo ScriptContextCmd
opts = Opt.info (parseScriptContextCmd <**> Opt.helper) Opt.fullDesc

parseScriptContextCmd :: Parser ScriptContextCmd
parseScriptContextCmd = parseGenerateDummy <|> parseGenerateTxBody
 where
  parseGenerateDummy :: Parser ScriptContextCmd
  parseGenerateDummy =
    flag' GenerateDummyScriptContextRedeemer
      (  long "generate"
      <> help "Create a dummy script context redeemer"
      )


  parseGenerateTxBody :: Parser ScriptContextCmd
  parseGenerateTxBody =
    GenerateScriptContextRedeemerTxBody
      <$> strOption ( long "generate-tx"
                    <> metavar "FILE"
                    <> help "Create a script context from a tx body."
                    <> Opt.completer (Opt.bashCompleter "file")
                    )
      <*> pConsensusModeParams
      <*> pNetworkId

data ScriptContextCmd
  = GenerateDummyScriptContextRedeemer
  | GenerateScriptContextRedeemerTxBody
      FilePath
      AnyConsensusModeParams
      NetworkId

runScriptContextCmd :: ScriptContextCmd -> IO ()
runScriptContextCmd GenerateDummyScriptContextRedeemer =
  LB.writeFile "example/work/script-context.redeemer" sampleTestScriptContextDataJSON
runScriptContextCmd (GenerateScriptContextRedeemerTxBody txbodyfile cModeParams nid) = do
      eTxBodyRedeemer <- runExceptT $ txToRedeemer txbodyfile cModeParams nid
      case eTxBodyRedeemer of
        Left err -> print err
        Right () -> return ()

pConsensusModeParams :: Parser AnyConsensusModeParams
pConsensusModeParams = asum
  [ Opt.flag' (AnyConsensusModeParams ShelleyModeParams)
      (  Opt.long "shelley-mode"
      <> Opt.help "For talking to a node running in Shelley-only mode."
      )
  , Opt.flag' ()
      (  Opt.long "byron-mode"
      <> Opt.help "For talking to a node running in Byron-only mode."
      )
       *> pByronConsensusMode
  , Opt.flag' ()
      (  Opt.long "cardano-mode"
      <> Opt.help "For talking to a node running in full Cardano mode (default)."
      )
       *> pCardanoConsensusMode
  , -- Default to the Cardano consensus mode.
    pure . AnyConsensusModeParams . CardanoModeParams $ EpochSlots defaultByronEpochSlots
  ]
 where
   pCardanoConsensusMode :: Parser AnyConsensusModeParams
   pCardanoConsensusMode = AnyConsensusModeParams . CardanoModeParams <$> pEpochSlots
   pByronConsensusMode :: Parser AnyConsensusModeParams
   pByronConsensusMode = AnyConsensusModeParams . ByronModeParams <$> pEpochSlots

defaultByronEpochSlots :: Word64
defaultByronEpochSlots = 21600

pNetworkId :: Parser NetworkId
pNetworkId =
  pMainnet' <|> fmap Testnet pTestnetMagic
 where
   pMainnet' :: Parser NetworkId
   pMainnet' =
    Opt.flag' Mainnet
      (  Opt.long "mainnet"
      <> Opt.help "Use the mainnet magic id."
      )

pTestnetMagic :: Parser NetworkMagic
pTestnetMagic =
  NetworkMagic <$>
    Opt.option Opt.auto
      (  Opt.long "testnet-magic"
      <> Opt.metavar "NATURAL"
      <> Opt.help "Specify a testnet magic id."
      )

pEpochSlots :: Parser EpochSlots
pEpochSlots =
  EpochSlots <$>
    Opt.option Opt.auto
      (  Opt.long "epoch-slots"
      <> Opt.metavar "NATURAL"
      <> Opt.help "The number of slots per epoch for the Byron era."
      <> Opt.value defaultByronEpochSlots -- Default to the mainnet value.
      <> Opt.showDefault
      )
