# jsonparser

json reader

解析部分代码使用 mORMot中的Json解析处理。只保留了数据读取过程处理，不生成Variant对象。

解决大数据量（特殊情况下）读取时，出现内存无法分配问题。


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


