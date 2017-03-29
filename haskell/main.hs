module Main where

import qualified Data.ByteString as BS (readFile, unpack)
import qualified Parser

main = do
  indata <- BS.readFile "../out"
  let buf = map fromEnum (BS.unpack indata)
  let result = Parser.parseData buf
  print result
  return ()