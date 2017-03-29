module Parser (
    Dependency (..)
  , Type (..)
  , Prototype (..)
  , Rutine (..)
  , Inst (..)
  , Module (..)
  , parseData
  ) where

import Data.Bits ((.&.), (.|.), shift)
import Data.Char (chr)

import Control.Monad.Trans.State

-- Basic Types --

data Dependency = Dep String [Int] deriving Show
data Type = ImportType Int String deriving Show
data Prototype = Proto [Int] [Int] deriving Show
data Rutine =
    ImportRut Int String
  | InternalRut String [Int] [Inst]
  deriving Show
data Constant =
    NullC
  | BinaryC [Int]
  | ArrayC  [Int]
  | TypeC   Int
  | RutineC Int
  | CallC   Int [Int]
  deriving Show
data Inst =
    ICall Int [Int] [Int]
  | IEnd
  | ICpy Int Int
  | ICns Int Int
  | ILbl Int
  | IJmp Int
  | IJif Int Int
  | INif Int Int
  deriving Show
data Module = Module [Dependency] [Type] [Prototype] [Rutine] [Constant] deriving Show

-- Parsing Primitives --

-- State monad with a byte stream as state
type Parser a = State [Int] a

-- Types that can be parsed from a byte stream
class Parse a where
  parse :: Parser a

unsupported msg = error ("Unsupported: " ++ msg)

-- Reads a single byte from the stream
readByte :: Parser Int
readByte = state $ \(x:xs) -> (x, xs)

-- Reads a variable length integer from the stream
-- For each byte, if it starts with 1 means isn't the last,
-- otherwise is the last byte, so each byte has 7 bits of data,
-- then the data bits are concatenated in big-endian order
readInt :: Parser Int
readInt = do
  x <- readByte
  let byte = x .&. 0x7f
  if (x .&. 0x80) == 0
  then return byte
  else do
    next <- readInt
    return $ (byte `shift` 7) .|. next

-- First reads an variable length integer from the stream, which is the
-- size of the string in bytes, and then reads the rest of the bytes
readStr :: Parser String
readStr = do
  len <- readInt
  buf <- get
  put $ drop len buf
  return $ (take len . map chr) buf

-- Parses n of any type that can be parsed
parseN :: (Parse a) => Int -> Parser [a]
parseN 0 = return []
parseN n = do
  x <- parse
  xs <- parseN (n-1)
  return (x:xs)

-- Reads an int from the stream, and then parses n values of any type
-- that can be parsed
parse' :: (Parse a) => Parser [a]
parse' = readInt >>= parseN

instance Parse Int where
  parse = readInt

-- Parsing Procedures --

instance Parse Dependency where
  parse = do
    name <- readStr
    paramCount <- readInt
    if paramCount > 0
    then unsupported "Import parameters"
    else return $ Dep name []

instance Parse Type where
  parse = do
    kind <- readInt
    mod  <- readInt
    name <- readStr
    case kind of
      0 -> error "Null type"
      1 -> unsupported "Internal Type"
      2 -> return $ ImportType mod name
      3 -> unsupported "Use Type"
      k -> error ("Unknown type kind " ++ show k)

instance Parse Prototype where
  parse = do
    ins <- parse'
    outs <- parse'
    return $ Proto ins outs

parseRutine :: [Prototype] -> Prototype -> Parser Rutine
parseRutine protos proto = do
  kind <- readInt
  case kind of
    0 -> error "Null Rutine"
    1 -> do
      name <- readStr
      regs <- parse'
      instCount <- readInt
      insts <- sequence $ take instCount $ repeat (readInt >>= inst)
      return $ InternalRut name regs insts
    2 -> do
      mod <- readInt
      name <- readStr
      return $ ImportRut mod name
    3 -> unsupported "Use Rutine"
    k -> error ("Unknown rutine kind " ++ show k)
  where
    inst :: Int -> Parser Inst
    inst 0 = return IEnd
    inst 1 = do a<-readInt; b<-readInt; return (ICpy a b)
    inst 2 = do a<-readInt; b<-readInt; return (ICns a b)
    inst 5 = do l<-readInt; return (ILbl l)
    inst 6 = do l<-readInt; return (IJmp l)
    inst 7 = do l<-readInt; a<-readInt; return (IJif l a)
    inst 8 = do l<-readInt; a<-readInt; return (INif l a)
    inst n | n<16 = unsupported ("Instruction " ++ show n)
    inst n' = do
      let n = n' - 16
      let (Proto ins' outs') = protos !! n
      ins <- parseN (length ins')
      outs <- parseN (length outs')
      return $ ICall n ins outs

parseConstant :: [Prototype] -> Parser (Constant, Int)
parseConstant protos = do
  let return' x = return (x, 1)
  kind <- readInt
  case kind of
    0 -> return' NullC
    1 -> do
      size <- readInt
      buf <- get
      put $ drop size buf
      return' $ BinaryC (take size buf)
    2 -> do
      xs <- parse'
      return' $ ArrayC xs
    3 -> do
      n <- readInt
      return' $ TypeC n
    4 -> do
      n <- readInt
      return' $ RutineC n
    n | n<16 -> fail $ "Unknown Constant Kind " ++ show n
    n' -> do
      let n = n' - 16
      let (Proto ins' outs') = protos !! n
      ins <- parseN (length ins')
      return (CallC n ins, length outs')


parseRutines :: [Prototype] -> Parser [Rutine]
parseRutines protos = mapM (parseRutine protos) protos

parseConstants :: [Prototype] -> Parser [Constant]
parseConstants protos = readInt >>= helper where
  helper :: Int -> Parser[Constant]
  helper 0 = return []
  helper n | n<0 = error "Negative Cosntant Count"
  helper n = do
    (x, outs) <- parseConstant protos
    xs <- helper (n-outs)
    return (x:xs)

-- Parses a null terminated string, and verifies that it's exactly "Cobre ~1"
checkMagic :: Parser Bool
checkMagic = do
  buf <- get
  let str = map chr $ takeWhile (/= 0) buf
  put $ drop (length str + 1) buf
  return $ str == "Cobre ~1"

parseData :: [Int] -> Module
parseData buf = (evalState parseAll buf) where
  parseAll :: Parser Module
  parseAll = do
    valid <- checkMagic
    if valid then do
      deps  <- parse'
      types <- parse'
      protos <- parse'
      rutines <- parseRutines protos
      constants <- parseConstants protos
      return (Module deps types protos rutines constants)
    else error "Unmatched magic string"
