//   Copyright (c) 2012, John Evans
//
//   http://www.lucastudios.com/contact
//   John: https://plus.google.com/u/0/115427174005651655317/about
//
//   Licensed under the Apache License, Version 2.0 (the "License");
//   you may not use this file except in compliance with the License.
//   You may obtain a copy of the License at
//
//       http://www.apache.org/licenses/LICENSE-2.0
//
//   Unless required by applicable law or agreed to in writing, software
//   distributed under the License is distributed on an "AS IS" BASIS,
//   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//   See the License for the specific language governing permissions and
//   limitations under the License.

/** XML Parser */
class XmlParser {
  final String _xml;
  final Queue<XmlElement> _scopes;
  XmlElement _root;

  static XmlElement _parse(String xml)
  {
    XmlParser p = new XmlParser._internal(xml);

    final XmlTokenizer t = new XmlTokenizer(p._xml);

    p._parseElement(t);

    return p._root;
  }

  XmlParser._internal(this._xml)
  :
    _scopes = new Queue<XmlElement>()
  ;

  void _parseElement(XmlTokenizer t){

    _XmlToken tok = t.next();

    while(tok != null){
      _assertKind(tok, _XmlToken.LT);

      _processTag(t);

      // finished.
      if (_scopes.isEmpty()) return;

      tok = t.next();
    }
  }

  _processTag(XmlTokenizer t){
    _XmlToken next = t.next();

// TODO handle comment nodes
//    if (next.kind == _XmlToken.BANG){
//      // possible comment node
//      return;
//    }

    if (next.kind == _XmlToken.SLASH){
      // this is a close tag

      next = t.next();
      _assertKind(next, _XmlToken.STRING);

      if (_peek().tagName != next._str){
        throw new XmlException.withDebug(
        'Expected closing tag "${_peek().tagName}"'
        ' but found "${next._str}" instead.', _xml, next._location);
      }

      next = t.next();
      _assertKind(next, _XmlToken.GT);

      _pop();

      return;
    }

    //otherwise this is an open tag

    _assertKind(next, _XmlToken.STRING);

    //TODO check tag name for invalid chars

    XmlElement newElement = new XmlElement(next._str);

    if (_root == null){
      //set to root and push
      _root = newElement;
      _push(_root);
    } else{
      //add child to current scope
      _peek().addChild(newElement);
      _push(newElement);
    }

    next = t.next();

    while(next != null){

      switch(next.kind){
        case _XmlToken.STRING:
          _processAttributes(t, next._str);
          break;
        case _XmlToken.GT:
          next = t.next();
          if (next.kind == _XmlToken.STRING){
            _processTextNode(t, next._str);
            _processTag(t);
          }else if (next.kind == _XmlToken.LT){
            _processTag(t);
          }else{
            throw new XmlException('Unexpected item "${next}" found.');
          }

          return;
        case _XmlToken.SLASH:
          next = t.next();
          _assertKind(next, _XmlToken.GT);
          _pop();
          return;
        default:
          throw new XmlException.withDebug(
            'Invalid xml ${next} found at this location.',
            _xml,
            next._location);
      }

      next = t.next();

      if (next == null){
        throw const Exception('Unexpected end of file.');
      }
    }
  }

  void _processTextNode(XmlTokenizer t, String text){
    //in text node all tokens until < are joined to a single string
    StringBuffer s = new StringBuffer();

    s.add(text);

    _XmlToken next = t.next();

    while(next.kind != _XmlToken.LT){

      s.add(next.toStringLiteral());

      next = t.next();

      if (next == null){
        throw const XmlException('Unexpected end of file.');
      }
    }

    _peek().addChild(new XmlText(s.toString()));
  }

  void _processAttributes(XmlTokenizer t, String attributeName){
    XmlElement el = _peek();

    void setAttribute(String name, String value){
      el.addChild(new XmlAttribute(name, value));
    }

    _XmlToken next = t.next();
    _assertKind(next, _XmlToken.EQ, "Must have an = after an"
      " attribute name.");

    //require quotes
    next = t.next();
    _assertKind(next, _XmlToken.QUOTE, "Quotes are required around"
      " attribute values.");

    next = t.next();
    StringBuffer s = new StringBuffer();

    while (next.kind != _XmlToken.QUOTE){

      s.add(next.toStringLiteral());

      next = t.next();

      if (next == null){
        throw const XmlException('Unexpected end of file.');
      }
    }

    setAttribute(attributeName, s.toString());
  }


  void _push(XmlElement element){
  //  print('pushing element ${element.tagName}');
    _scopes.addFirst(element);
  }
  XmlElement _pop(){
  //  print('popping element ${_peek().tagName}');
    _scopes.removeFirst();
  }
  XmlElement _peek() => _scopes.first();


  void _assertKind(_XmlToken tok, int matchID, [String info = null]){
    _XmlToken match = new _XmlToken(matchID);

    var msg = 'Expected ${match}, but found ${tok}. ${info == null ? "" :
      "\r$info"}';

    if (tok.kind != match.kind) {
      throw new XmlException.withDebug(msg, _xml, tok._location);
    }
  }
}
