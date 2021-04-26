# jsonparser

json reader


顺序读取`json`模式，降低数据转换和内存分配。

解决Dataset传输时数据量过大，标准的Json转换成对象出现峰值内存占用容易出现无法分配问题。


## code

```pascal
var
  parser: TJSONReader;
begin  
  
  parser.Init('{"hex": "\u4e2d\u6587\u6d4b\u8bd5"}', 1, -1);
  
  // 跳过第一个 { or [
  check(parser.GetDataType = jrkObject, 'Read Json data type, should be Object');
  
  // 读取Json对象的名称
  check(parser.GetNext = jrkString, 'Read attribute name');
  Check(parser.GetToken = 'hex');

  // 读取值
  Check(parser.GetNextNonWhiteChar = ':');
  check(parser.GetNext = jrkString);
  Check(parser.GetToken = '\u4e2d\u6587\u6d4b\u8bd5', 'read token err');
  Check(parser.AsStr = '中文测试');
end;
```



## 开发环境

- windows pro 7 
- delphi 2010 


