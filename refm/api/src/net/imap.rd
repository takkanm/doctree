このライブラリは Internet Message Access Protocol (IMAP) の
クライアントライブラリです。[[RFC:2060]] を元に
実装されています。

=== IMAP の概要

IMAPを利用するには、まずサーバに接続し、
[[m:Net::IMAP#authenticate]] もしくは
[[m:Net::IMAP#login]] で認証します。
IMAP ではメールボックスという概念が重要です。
メールボックスは階層的な名前を持ちます。
各メールボックスはメールを保持することができます。
メールボックスの実装はサーバソフトウェアによって異なります。
Unixシステムでは、ディレクトリ階層上の
ファイルを個々のメールボックスとみなして実装されることが多いです。

メールボックス内のメッセージ(メール)を処理する場合、
まず [[m:Net::IMAP#select]] もしくは
[[m:Net::IMAP#examine]] で処理対象のメールボックスを
指定する必要があります。これらの操作が成功したならば、
「selected」状態に移行し、そのメールボックスが「処理対象の」
メールボックスとなります。このようにしてメールボックスを
選択してから、selected状態を終える(別のメールボックスを選択したり、
接続を終了したり)までをセッションと呼びます。

メッセージには2種類の識別子が存在します。message sequence number と
UID です。

message sequence number はメールボックス内の各メッセージに1から順に
振られた番号です。セッション中に処理対象のメールボックスに
新たなメッセージが追加された場合、そのメッセージの
message sequence number は
最後のメッセージの message sequence number+1となります。
メッセージをメールボックスから消した場合には、連番の穴を埋めるように
message sequence number が付け替えられます。

一方、UID はセッションを越えて恒久的に保持されます。
あるメールボックス内の異なる2つのメッセージが同じ  UID 
を持つことはありません。
これは、メッセージがメールボックスから削除された後でも成立します。

しかし、UID はメールボックス内で昇順であることが
規格上要請されているので、
IMAP を使わないメールアプリケーションがメールの順番を
変えてしまった場合は、UID が振り直されます。

=== 例

デフォルトのメールボックス(INBOX)の送り元とサブジェクトを表示する。
  imap = Net::IMAP.new('mail.example.com')
  imap.authenticate('LOGIN', 'joe_user', 'joes_password')
  imap.examine('INBOX')
  imap.search(["RECENT"]).each do |message_id|
    envelope = imap.fetch(message_id, "ENVELOPE")[0].attr["ENVELOPE"]
    puts "#{envelope.from[0].name}: \t#{envelope.subject}"
  end

2003年4月のメールをすべて Mail/sent-mail から "Mail/sent-apr03" へ移動させる

  imap = Net::IMAP.new('mail.example.com')
  imap.authenticate('LOGIN', 'joe_user', 'joes_password')
  imap.select('Mail/sent-mail')
  if not imap.list('Mail/', 'sent-apr03')
    imap.create('Mail/sent-apr03')
  end
  imap.search(["BEFORE", "30-Apr-2003", "SINCE", "1-Apr-2003"]).each do |message_id|
    imap.copy(message_id, "Mail/sent-apr03")
    imap.store(message_id, "+FLAGS", [:Deleted])
  end
  imap.expunge

=== スレッド安全性
Net::IMAP は並列実行をサポートしています。例として、

  imap = Net::IMAP.new("imap.foo.net", "imap2")
  imap.authenticate("cram-md5", "bar", "password")
  imap.select("inbox")
  fetch_thread = Thread.start { imap.fetch(1..-1, "UID") }
  search_result = imap.search(["BODY", "hello"])
  fetch_result = fetch_thread.value
  imap.disconnect

とすると FETCH コマンドと SEARCH コマンドを並列に実行します。

=== エラーについて
IMAP サーバは以下の3種類のエラーを送ります。

: NO
  コマンドが正常に完了しなかったことを意味します。
  例えば、ログインでのユーザ名/パスワードが間違っていた、
  選択したメールボックスが存在しない、などです。

: BAD
  クライアントからのリクエストをサーバが理解できなかった
  ことを意味します。
  クライアントの現在の状態では使えないコマンドを使おうとした
  場合にも発生します。例えば、
  selected状態(SELECT/EXAMINEでこの状態に移行する)にならずに
  SEARCH コマンドを使おうとした場合に発生します。
  サーバの内部エラー(ディスクが壊れたなど)の場合も
  このエラーが発生します。

: BYE
  サーバが接続を切ろうとしていることを意味します。
  これは通常のログアウト処理で発生します。
  また、ログイン時にサーバが(なんらかの理由で)接続
  したくない場合にも発生します。
  それ以外では、サーバがシャットダウンする場合か
  サーバがタイムアウトする場合に発生します。

これらのエラーはそれぞれ
  * [[c:Net::IMAP::NoResponseError]]
  * [[c:Net::IMAP::BadResponseError]]
  * [[c:Net::IMAP::ByeResponseError]]
という例外クラスに対応しています。
原理的には、これらの例外はサーバにコマンドを送った場合には
常に発生する可能性があります。しかし、このドキュメントでは
よくあるエラーのみ解説します。

IMAP は Socket で通信をするため、IMAPクラスのメソッドは
Socket 関連のエラーが発生するかもしれません。例えば、
通信中に接続が切れると [[c:Errno::EPIPE]] 例外が
発生します。詳しくは [[c:Socket]] などを見てください。

[[c:Net::IMAP::DataFormatError]]、
[[c:Net::IMAP::ResponseParseError]] という例外クラスも
存在します。前者はデータのフォーマットが正しくない場合に、
後者はサーバからのレスポンスがパースできない場合に発生します。
これらのエラーはこのライブラリもしくはサーバに深刻な問題が
あることを意味します。

=== References

  * [IMAP]
    M. Crispin, "INTERNET MESSAGE ACCESS PROTOCOL - VERSION 4rev1",
    RFC 2060, December 1996.

  * [LANGUAGE-TAGS]
    Alvestrand, H., "Tags for the Identification of
    Languages", RFC 1766, March 1995.

  * [MD5]
    Myers, J., and M. Rose, "The Content-MD5 Header Field", RFC
    1864, October 1995.

  * [MIME-IMB]
    Freed, N., and N. Borenstein, "MIME (Multipurpose Internet
    Mail Extensions) Part One: Format of Internet Message Bodies", RFC
    2045, November 1996.

  * [RFC-822]
    Crocker, D., "Standard for the Format of ARPA Internet Text
    Messages", STD 11, RFC 822, University of Delaware, August 1982.

  * [RFC-2087]
    Myers, J., "IMAP4 QUOTA extension", RFC 2087, January 1997.

  * [RFC-2086]
    Myers, J., "IMAP4 ACL extension", RFC 2086, January 1997.

  * [OSSL]
    http://www.openssl.org

  * [RSSL]
    http://savannah.gnu.org/projects/rubypki



= class Net::IMAP < Object

IMAP 接続を表現するクラスです。

== Class Methods

--- new(host, port = 143, usessl = false, certs = nil, verify = false) -> Net::IMAP
--- new(host, options) -> Net::IMAP

新たな Net::IMAP オブジェクトを生成し、指定したホストの
指定したポートに接続し、接続語の IMAP オブジェクトを返します。

usessl が真ならば、サーバに繋ぐのに SSL/TLS を用います。
SSL/TLS での接続には OpenSSL と [[lib:openssl]] が使える必要があります。
certs は利用する証明書のファイル名もしくは証明書があるディレクトリ名を
文字列で渡します。
certs に nil を渡すと、OpenSSL のデフォルトの証明書を使います。
verify は接続先を検証するかを真偽値で設定します。
真が [[m:OpenSSL::SSL::VERIFY_PEER]] に、
偽が [[m:OpenSSL::SSL::VERIFY_NONE]] に対応します。

パラメータは Hash で渡すこともできます。以下のキーを使うことができます。
  * :port ポート番号
    省略時は SSL/TLS 使用時→993 不使用時→143 となります。
  * :ssl OpenSSL に渡すパラメータをハッシュで指定します。
    省略時は SSL/TLS を使わず接続します。
    これで渡せるパラメータは
    [[m:OpenSSL::SSL::SSLContext#set_params]] と同じです。
これの :ssl パラメータを使うことで、OpenSSL のパラメータを詳細に
調整できます。


例
  imap = Net::IMAP.new('imap.example.com', :port => 993,
                   :ssl => { :verify_mode => OpenSSL::SSL::VERIFY_PEER,
                             :timeout => 600 } )

@param host 接続するホスト名の文字列
@param port 接続するポート番号
@param usessl 真でSSL/TLSを使う
@param certs 証明書のファイル名/ディレクトリ名の文字列
@param verify 真で接続先を検証する
@param options 各種接続パラメータのハッシュ

--- debug -> bool

デバッグモードが on になっていれば真を返します。

@see [[m:Net::IMAP#debug=]]

--- debug=(val)
デバッグモードの on/off をします。

真を渡すと on になります。

@param val 設定するデバッグモードの on/off の真偽値
@see [[m:Net::IMAP#debug]]

--- add_authenticator(auth_type, authenticator) -> ()
[[m:Net::IMAP#authenticate]] で使う 
認証用クラスを設定します。

imap ライブラリに新たな認証方式を追加するために用います。

通常は使う必要はないでしょう。もしこれを用いて
認証方式を追加する場合は net/imap.rb の
Net::IMAP::LoginAuthenticator などを参考にしてください。

@param auth_type 認証の種類(文字列)
@param authenticator 認証クラス(Class オブジェクト)

--- decode_utf7(str) -> String
modified UTF-7 の文字列を UTF-8 の文字列に変換します。

modified UTF-7 は IMAP のメールボックス名に使われるエンコーディングで、
UTF-7 を修正したものです。

詳しくは [[RFC:2060]] の 5.1.3 を参照してください。

Net::IMAP ではメールボックス名のエンコードを自動的変換「しない」
ことに注意してください。必要があればユーザが変換すべきです。

@param str 変換対象の modified UTF-7 でエンコードされた文字列
@see [[m:Net::IMAP.encode_utf7]]
--- encode_utf7(str) -> String
UTF-8 の文字列を modified UTF-7 の文字列に変換します。

modified UTF-7 は IMAP のメールボックス名に使われるエンコーディングで、
UTF-7 を修正したものです。

詳しくは [[m:Net::IMAP.encode_utf7]] を見てください。

@param str 変換対象の UTF-8 でエンコードされた文字列
@see [[m:Net::IMAP.decode_utf7]]

#@since 1.9.1

--- format_date(time) -> String
時刻オブジェクトを IMAP の日付フォーマットでの文字列に変換します。

  Net::IMAP.format_date(Time.new(2011, 6, 20))
  # => "20-Jun-2011"

@param time 変換する時刻オブジェクト

--- format_datetime(time) -> String
時刻オブジェクトを IMAP の日付時刻フォーマットでの文字列に変換します

  Net::IMAP.format_datetime(Time.new(2011, 6, 20, 13, 20, 1))
  # => "20-Jun-2011 13:20 +0900"

@param time 変換する時刻オブジェクト

--- max_flag_count -> Integer
サーバからのレスポンスに含まれる flag の上限を返します。

これを越えた flag がレスポンスに含まれている場合は、
[[c:Net::IMAP::FlagCountError]] 例外が発生します。

@see [[m:Net::IMAP#max_flag_count=]]

--- max_flag_count=(count)
サーバからのレスポンスに含まれる flag の上限を設定します。

これを越えた flag がレスポンスに含まれている場合は、
[[c:Net::IMAP::FlagCountError]] 例外が発生します。

デフォルトは 10000 です。通常は変える必要はないでしょう。

@param count 設定する最大値の整数
@see [[m:Net::IMAP#max_flag_count=]]
#@end

== Methods

--- greeting -> Net::IMAP::UntaggedResponse
サーバから最初に送られてくるメッセージ(greeting message)
を返します。

--- responses -> { String => [object] }
#@todo

Returns recorded untagged responses.

ex).

  imap.select("inbox")
  p imap.responses["EXISTS"].last
  #=> 2
  p imap.responses["UIDVALIDITY"].last
  #=> 968263756

--- disconnect -> nil
サーバとの接続を切断します。

@see [[m:Net::IMAP#disconnected?]]

--- capability -> [String]
CAPABILITY コマンドを送ってサーバがサポートしている
機能(capabilities)のリストを文字列の配列として返します。

capability は IMAP に関連する RFC などで定義されています。

  imap.capability
  # => ["IMAP4REV1", "UNSELECT", "IDLE", "NAMESPACE", "QUOTA", ... ]

--- noop -> Net::IMAP::TaggedResponse
NOOP コマンドを送ります。

このコマンドは何もしません。

--- logout -> Net::IMAP::TaggedResponse
LOGOUT コマンドを送り、コネクションを切断することを
サーバに伝えます。

--- authenticate(auth_type, arg...)
#@todo

Sends an AUTEHNTICATE command to authenticate the client.
The auth_type parameter is a string that represents
the authentication mechanism to be used. Currently Net::IMAP
supports "LOGIN" and "CRAM-MD5" for the auth_type.

ex).

  imap.authenticate('LOGIN', user, password)

auth_type としては以下がサポートされています。
  * "LOGIN"
  * "PLAIN"
  * "CRAM-MD5"
  * "DIGEST-MD5"

--- login(user, password) -> Net::IMAP::TaggedResponse
LOGIN コマンドを送り、平文でパスワードを送りクライアント
ユーザを認証します。

[[m:Net::IMAP#authenticate]] で "LOGIN" を使うのとは異なる
ことに注意してください。authenticate では AUTHENTICATE コマンドを
送ります。

認証成功時には
認証成功レスポンスを返り値として返します。

認証失敗時には例外が発生します。

@param user ユーザ名文字列
@param password パスワード文字列
@raise Net::IMAP::NoResponseError 認証に失敗した場合に発生します

--- select(mailbox) -> Net::IMAP::TaggedResponse
SELECT コマンドを送り、指定したメールボックスを処理対象の
メールボックスにします。

このコマンドが成功すると、クライアントの状態が「selected」になります。

このコマンドを実行した直後に [[m:Net::IMAP#responses]]["EXISTS"].last
を調べると、メールボックス内のメールの数がわかります。
また、[[m:Net::IMAP#responses]]["RECENT"].lastで、
最新のメールの数がわかります。
これらの値はセッション中に変わりうることに注意してください。
[[m:Net::IMAP#add_response_handler]] を使うとそのような更新情報を
即座に取得できます。

@param mailbox 処理対象としたいメールボックスの名前(文字列)
@raise Net::IMAP::NoResponseError mailboxが存在しない等の理由でコマンドの実行に失敗
       した場合に発生します。

--- examine(mailbox) -> Net::IMAP::TaggedResponse
EXAMINE コマンドを送り、指定したメールボックスを処理対象の
メールボックスにします。

[[m:Net::IMAP#select]] と異なりセッション中はメールボックスが
読み取り専用となります。それ以外は select と同じです。

@param mailbox 処理対象としたいメールボックスの名前(文字列)
@raise Net::IMAP::NoResponseError mailboxが存在しない等の理由でコマンドの実行に失敗
       した場合に発生します。

--- create(mailbox) -> Net::IMAP::TaggedResponse
CREATE  コマンドを送り、新しいメールボックスを作ります。

@param mailbox 新しいメールボックスの名前(文字列)
@raise Net::IMAP::NoResponseError 指定した名前のメールボックスが作れなかった場合に発生します

--- delete(mailbox) -> Net::IMAP::TaggedResponse
DELETE コマンドを送り、指定したメールボックスを削除します。

@param mailbox 削除するメールボックスの名前(文字列)
@raise Net::IMAP::NoResponseError 指定した名前のメールボックスを削除した場合
       に発生します。指定した名前のメールボックスが存在しない場合や、
       ユーザにメールボックスを削除する権限がない場合に発生します。

--- rename(mailbox, newname)
#@todo

Sends a RENAME command to change the name of the mailbox to
the newname.

--- subscribe(mailbox)
#@todo

Sends a SUBSCRIBE command to add the specified mailbox name to
the server's set of "active" or "subscribed" mailboxes.

--- unsubscribe(mailbox)
#@todo

Sends a UNSUBSCRIBE command to remove the specified mailbox name
from the server's set of "active" or "subscribed" mailboxes.

--- list(refname, mailbox)
#@todo

Sends a LIST command, and returns a subset of names from
the complete set of all names available to the client.
The return value is an array of [[c:Net::IMAP::MailboxList]].

ex).

  imap.create("foo/bar")
  imap.create("foo/baz")
  p imap.list("", "foo/%")
  #=> [#<Net::IMAP::MailboxList attr=[:Noselect], delim="/", name="foo/">, #<Net::IMAP::MailboxList attr=[:Noinferiors, :Marked], delim="/", name="foo/bar">, #<Net::IMAP::MailboxList attr=[:Noinferiors], delim="/", name="foo/baz">]

--- lsub(refname, mailbox)
#@todo

Sends a LSUB command, and returns a subset of names from the set
of names that the user has declared as being "active" or
"subscribed".
The return value is an array of [[c:Net::IMAP::MailboxList]].

--- status(mailbox, attr)
#@todo

Sends a STATUS command, and returns the status of the indicated
mailbox.
return value is a hash of attributes.

ex).

  p imap.status("inbox", ["MESSAGES", "RECENT"])
  #=> {"RECENT"=>0, "MESSAGES"=>44}

--- append(mailbox, message, flags = nil, date_time = nil)
#@todo

Sends a APPEND command to append the message to the end of
the mailbox.

ex).

  imap.append("inbox", <<EOF.gsub(/\n/, "\r\n"), [:Seen], Time.now)
  Subject: hello
  From: shugo@ruby-lang.org
  To: shugo@ruby-lang.org
  
  hello world
  EOF

--- check -> Net::IMAP::TaggedResponse
CHECK コマンドを送り、現在処理しているメールボッススの
チェックポイントを要求します。

チェックポイントの要求とは、サーバ内部で保留状態になっている
操作を完了させることを意味します。例えばメモリ上にあるメールの
データをディスクに書き込むため、fsyncを呼んだりすることです。
実際に何が行なわれるかはサーバの実装によりますし、何も行なわれない
場合もあります。


--- close -> Net::IMAP::TaggedResponse
CLOSE コマンドを送り、処理中のメールボックスを閉じます。

このコマンドによって、どのメールボックスも選択されていない
状態に移行します。
そして \Deleted フラグが付けられたメールがすべて削除されます。

--- expunge 
#@todo

Sends a EXPUNGE command to permanently remove from the currently
selected mailbox all messages that have the \Deleted flag set.

--- search(keys, charset = nil)
--- uid_search(keys, charset = nil)
#@todo

Sends a SEARCH command to search the mailbox for messages that
match the given searching criteria, and returns message sequence
numbers (search) or unique identifiers (uid_search).

ex).

  p imap.search(["SUBJECT", "hello"])
  #=> [1, 6, 7, 8]
  p imap.search('SUBJECT "hello"')
  #=> [1, 6, 7, 8]

--- fetch(set, attr)
--- uid_fetch(set, attr)
#@todo

Sends a FETCH command to retrieve data associated with a message
in the mailbox. the set parameter is a number or an array of
numbers or a Range object. the number is a message sequence
number (fetch) or a unique identifier (uid_fetch).
The return value is an array of [[c:Net::IMAP::FetchData]].

ex).

  p imap.fetch(6..8, "UID")
  #=> [#<Net::IMAP::FetchData seqno=6, attr={"UID"=>98}>, #<Net::IMAP::FetchData seqno=7, attr={"UID"=>99}>, #<Net::IMAP::FetchData seqno=8, attr={"UID"=>100}>]
  p imap.fetch(6, "BODY[HEADER.FIELDS (SUBJECT)]")
  #=> [#<Net::IMAP::FetchData seqno=6, attr={"BODY[HEADER.FIELDS (SUBJECT)]"=>"Subject: test\r\n\r\n"}>]
  data = imap.uid_fetch(98, ["RFC822.SIZE", "INTERNALDATE"])[0]
  p data.seqno
  #=> 6
  p data.attr["RFC822.SIZE"]
  #=> 611
  p data.attr["INTERNALDATE"]
  #=> "12-Oct-2000 22:40:59 +0900"
  p data.attr["UID"]
  #=> 98

--- store(set, attr, flags)
--- uid_store(set, attr, flags)
#@todo

Sends a STORE command to alter data associated with a message
in the mailbox. the set parameter is a number or an array of
numbers or a Range object. the number is a message sequence
number (store) or a unique identifier (uid_store).
The return value is an array of [[c:Net::IMAP::FetchData]].

ex).

  p imap.store(6..8, "+FLAGS", [:Deleted])
  #=> [#<Net::IMAP::FetchData seqno=6, attr={"FLAGS"=>[:Seen, :Deleted]}>, #<Net::IMAP::FetchData seqno=7, attr={"FLAGS"=>[:Seen, :Deleted]}>, #<Net::IMAP::FetchData seqno=8, attr={"FLAGS"=>[:Seen, :Deleted]}>]

--- copy(set, mailbox)
--- uid_copy(set, mailbox)
#@todo

Sends a COPY command to copy the specified message(s) to the end
of the specified destination mailbox. the set parameter is
a number or an array of numbers or a Range object. the number is
a message sequence number (copy) or a unique identifier (uid_copy).

--- sort(sort_keys, search_keys, charset)
--- uid_sort(sort_keys, search_keys, charset)
#@todo

Sends a SORT command to sort messages in the mailbox.

ex).

  p imap.sort(["FROM"], ["ALL"], "US-ASCII")
  #=> [1, 2, 3, 5, 6, 7, 8, 4, 9]
  p imap.sort(["DATE"], ["SUBJECT", "hello"], "US-ASCII")
  #=> [6, 7, 8, 1]

--- setquota(mailbox, quota)
#@todo

Sends a SETQUOTA command along with the specified mailbox and
quota.  If quota is nil, then quota will be unset for that
mailbox.  Typically one needs to be logged in as server admin
for this to work.  The IMAP quota commands are described in
[[RFC:2087]].

--- getquota(mailbox)
#@todo

Sends the GETQUOTA command along with specified mailbox.
If this mailbox exists, then an array containing a
[[c:Net::IMAP::MailboxQuota]] object is returned.  This
command generally is only available to server admin.

--- getquotaroot(mailbox)
#@todo

Sends the GETQUOTAROOT command along with specified mailbox.
This command is generally available to both admin and user.
If mailbox exists, returns an array containing objects of
[[c:Net::IMAP::MailboxQuotaRoot]] and [[c:Net::IMAP::MailboxQuota]].

--- setacl(mailbox, user, rights)
#@todo

Sends the SETACL command along with mailbox, user and the
rights that user is to have on that mailbox.  If rights is nil,
then that user will be stripped of any rights to that mailbox.
The IMAP ACL commands are described in [[RFC:2086]].

--- getacl(mailbox)
#@todo

Send the GETACL command along with specified mailbox.
If this mailbox exists, an array containing objects of
[[c:Net::IMAP::MailboxACLItem]] will be returned.

--- add_response_handler(handler = Proc.new)
#@todo

Adds a response handler.

ex).

  imap.add_response_handler do |resp|
    p resp
  end

--- remove_response_handler(handler)
#@todo

Removes the response handler.

--- response_handlers
#@todo

Returns all response handlers.

#@since 1.9.1
--- starttls(cxt = nil)
#@todo

Sends a STARTTLS command to start TLS session.
#@end

#@since 1.8.2
--- disconnected? -> bool

サーバとの接続が切断されていれば真を返します。

@see [[m:Net::IMAP#disconnect]]

#@end

--- thread(algorithm, search_keys, charset)
#@todo

As for #search(), but returns message sequence numbers in threaded
format, as a Net::IMAP::ThreadMember tree.  The supported algorithms
are:

ORDEREDSUBJECT:: split into single-level threads according to subject,
                 ordered by date.
REFERENCES:: split into threads by parent/child relationships determined
              by which message is a reply to which.

Unlike #search(), +charset+ is a required argument.  US-ASCII
and UTF-8 are sample values.

See [SORT-THREAD-EXT] for more details.

--- uid_thread(algorithm, search_keys, charset)
#@todo

As for #thread(), but returns unique identifiers instead of 
message sequence numbers.

--- client_thread
--- client_thread=(th)
#@todo

The thread to receive exceptions.

--- idle
--- idle_done
#@todo

= class Net::IMAP::ContinuationRequest < Struct

Net::IMAP::ContinuationRequest represents command continuation requests.

The command continuation request response is indicated by a "+" token
instead of a tag.  This form of response indicates that the server is
ready to accept the continuation of a command from the client.  The
remainder of this response is a line of text.

  continue_req    ::= "+" SPACE (resp_text / base64)

== Instance Methods

--- data
#@todo

Returns the data ([[c:Net::IMAP::ResponseText]]).

--- raw_data
#@todo

Returns the raw data string.



= class Net::IMAP::UntaggedResponse < Struct

IMAP のタグ付きレスポンスを表すクラスです。

IMAP のレスポンスにはタグ付きのものとタグなしのものがあり、
タグなしのものはクライアントからのコマンド完了応答ではない
レスポンスです。

@see [[c:Net::IMAP::TaggedResponse]]

== Instance Methods

--- name -> String

レスポンスの名前(種類)を返します。

例えば以下のような値を返します。これらの具体的な意味は
[[RFC:2060]] を参考にしてください。
  * "OK"
  * "NO"
  * "BAD"
  * "BYE"
  * "PREAUTH"
  * "CAPABILITY"
  * "LIST"
  * "FLAGS"
  *  etc

--- data -> object

レスポンスを解析した結果のオブジェクトを返します。

レスポンスによって異なるオブジェクトを返します。
[[c:Net::IMAP::MailboxList]] であったりフラグを表わす
シンボルの配列であったりします。
Returns the data such as an array of flag symbols,
a [[c:Net::IMAP::MailboxList]] object....

--- raw_data -> String

レスポンス文字列を返します。

@see [[m:Net::IMAP::UntaggedResponse#data]]
= class Net::IMAP::TaggedResponse < Struct

IMAP のタグ付きレスポンスを表すクラスです。

IMAP のレスポンスにはタグ付きのものとタグなしのものがあり、
タグ付きのレスポンスはクライアントが発行したコマンドによる
操作が成功するか失敗するかのどちらかで
完了したことを意味します。タグによって
どのコマンドが完了したのかを示します。

@see [[c:Net::IMAP::UntaggedResponse]]

== Instance Methods

--- tag -> String

レスポンスに対応付けられたタグを返します。

--- name -> String

レスポンスの名前(種類)を返します。

例えば以下のような値を返します。これらの具体的な意味は
[[RFC:2060]] を参考にしてください。
  * "OK"
  * "NO"
  * "BAD"

--- data -> Net::IMAP::ResponseText 

レスポンスを解析したオブジェクトを返します。

@see [[c:Net::IMAP::ResponseText]]

--- raw_data -> String

レスポンス文字列を返します。

@see [[m:Net::IMAP::TaggedResponse#data]]

= class Net::IMAP::ResponseText < Struct

Net::IMAP::ResponseText represents texts of responses.
The text may be prefixed by the response code.

  resp_text       ::= ["[" resp_text_code "]" SPACE] (text_mime2 / text)
                      ;; text SHOULD NOT begin with "[" or "="

== Instance Methods

--- code
#@todo

Returns the response code. See [[c:Net::IMAP::ResponseCode]].

--- text
#@todo

Returns the text.



= class Net::IMAP::ResponseCode < Struct

Net::IMAP::ResponseCode represents response codes.

  resp_text_code  ::= "ALERT" / "PARSE" /
                      "PERMANENTFLAGS" SPACE "(" #(flag / "\*") ")" /
                      "READ-ONLY" / "READ-WRITE" / "TRYCREATE" /
                      "UIDVALIDITY" SPACE nz_number /
                      "UNSEEN" SPACE nz_number /
                      atom [SPACE 1*<any TEXT_CHAR except "]">]

== Instance Methods

--- name
#@todo

Returns the name such as "ALERT", "PERMANENTFLAGS", "UIDVALIDITY"....

--- data
#@todo

Returns the data if it exists.



= class Net::IMAP::MailboxList < Struct

Net::IMAP::MailboxList represents contents of the LIST response.

  mailbox_list    ::= "(" #("\Marked" / "\Noinferiors" /
                      "\Noselect" / "\Unmarked" / flag_extension) ")"
                      SPACE (<"> QUOTED_CHAR <"> / nil) SPACE mailbox


== Instance Methods

--- attr
#@todo

Returns the name attributes. Each name attribute is a symbol
capitalized by String#capitalize, such as :Noselect (not :NoSelect).

--- delim
#@todo

Returns the hierarchy delimiter

--- name
#@todo

Returns the mailbox name.



= class Net::IMAP::MailboxQuota < Struct

Net::IMAP::MailboxQuota represents contents of GETQUOTA response.
This object can also be a response to GETQUOTAROOT.  In the syntax
specification below, the delimiter used with the "#" construct is a
single space (SPACE).

   quota_list      ::= "(" #quota_resource ")"
   
   quota_resource  ::= atom SPACE number SPACE number
   
   quota_response  ::= "QUOTA" SPACE astring SPACE quota_list

== Instance Methods

--- mailbox
#@todo

The mailbox with the associated quota.

--- usage
#@todo

Current storage usage of mailbox.

--- quota
#@todo

Quota limit imposed on mailbox.



= class Net::IMAP::MailboxQuotaRoot < Struct

Net::IMAP::MailboxQuotaRoot represents part of the GETQUOTAROOT
response. (GETQUOTAROOT can also return Net::IMAP::MailboxQuota.)

  quotaroot_response
                  ::= "QUOTAROOT" SPACE astring *(SPACE astring)

== Instance Methods

--- mailbox
#@todo

The mailbox with the associated quota.

--- quotaroots
#@todo

Zero or more quotaroots that effect the quota on the
specified mailbox.



= class Net::IMAP::MailboxACLItem < Struct

Net::IMAP::MailboxACLItem represents response from GETACL.

  acl_data        ::= "ACL" SPACE mailbox *(SPACE identifier SPACE
                       rights)
  
  identifier      ::= astring
  
  rights          ::= astring

== Instance Methods

--- user
#@todo

Login name that has certain rights to the mailbox
that was specified with the getacl command.

--- rights
#@todo

The access rights the indicated user has to the
mailbox.



= class Net::IMAP::StatusData < Object

Net::IMAP::StatusData represents contents of the STATUS response.

== Instance Methods

--- mailbox
#@todo

Returns the mailbox name.

--- attr
#@todo

Returns a hash. Each key is one of "MESSAGES", "RECENT", "UIDNEXT",
"UIDVALIDITY", "UNSEEN". Each value is a number.



= class Net::IMAP::FetchData < Object

Net::IMAP::FetchData represents contents of the FETCH response.

== Instance Methods

--- seqno
#@todo

Returns the message sequence number.
(Note: not the unique identifier, even for the UID command response.)

--- attr
#@todo

Returns a hash. Each key is a data item name, and each value is
its value.

The current data items are:

: BODY
      A form of BODYSTRUCTURE without extension data.
: BODY[<section>]<<origin_octet>>
      A string expressing the body contents of the specified section.
: BODYSTRUCTURE
      An object that describes the [MIME-IMB] body structure of a message.
      See [[c:Net::IMAP::BodyTypeBasic]], [[c:Net::IMAP::BodyTypeText]],
      [[c:Net::IMAP::BodyTypeMessage]], [[c:Net::IMAP::BodyTypeMultipart]].
: ENVELOPE
      A [[c:Net::IMAP::Envelope]] object that describes the envelope
      structure of a message.
: FLAGS
      A array of flag symbols that are set for this message. flag symbols
      are capitalized by String#capitalize.
: INTERNALDATE
      A string representing the internal date of the message.
: RFC822
      Equivalent to BODY[].
: RFC822.HEADER
      Equivalent to BODY.PEEK[HEADER].
: RFC822.SIZE
      A number expressing the [[RFC:822]] size of the message.
: RFC822.TEXT
      Equivalent to BODY[TEXT].
: UID
      A number expressing the unique identifier of the message.



= class Net::IMAP::Envelope < Struct

Net::IMAP::Envelope represents envelope structures of messages.

== Instance Methods

--- date
#@todo

Retunns a string that represents the date.

--- subject
#@todo

Retunns a string that represents the subject.

--- from
#@todo

Retunns an array of [[c:Net::IMAP::Address]] that represents the from.

--- sender
#@todo

Retunns an array of [[c:Net::IMAP::Address]] that represents the sender.

--- reply_to
#@todo

Retunns an array of [[c:Net::IMAP::Address]] that represents the reply-to.

--- to
#@todo

Retunns an array of [[c:Net::IMAP::Address]] that represents the to.

--- cc
#@todo

Retunns an array of [[c:Net::IMAP::Address]] that represents the cc.

--- bcc
#@todo

Retunns an array of [[c:Net::IMAP::Address]] that represents the bcc.

--- in_reply_to
#@todo

Retunns a string that represents the in-reply-to.

--- message_id
#@todo

Retunns a string that represents the message-id.



= class Net::IMAP::Address < Struct

Net::IMAP::Address represents electronic mail addresses.

== Instance Methods

--- name
#@todo

Returns the phrase from [[RFC:822]] mailbox.

--- route
#@todo

Returns the route from [[RFC:822]] route-addr.

--- mailbox
#@todo

nil indicates end of [[RFC:822]] group.
If non-nil and host is nil, returns [[RFC:822]] group name.
Otherwise, returns [[RFC:822]] local-part

--- host
#@todo

nil indicates [[RFC:822]] group syntax.
Otherwise, returns [[RFC:822]] domain name.



= class Net::IMAP::ContentDisposition < Struct

Net::IMAP::ContentDisposition represents Content-Disposition fields.

== Instance Methods

--- dsp_type
#@todo

Returns the disposition type.

--- param
#@todo

Returns a hash that represents parameters of the Content-Disposition
field.



= class Net::IMAP::ThreadMember < Struct

Net::IMAP::ThreadMember represents a thread-node returned 
by [[m:Net::IMAP#thread]]

== Instance Methods

--- seqno
#@todo

The sequence number of this message.

--- children
#@todo

an array of [[c:Net::IMAP::ThreadMember]] objects for mail
items that are children of this in the thread.



= class Net::IMAP::BodyTypeBasic < Struct

Net::IMAP::BodyTypeBasic represents basic body structures of messages.

== Instance Methods

--- media_type
#@todo

Returns the content media type name as defined in [MIME-IMB].

--- subtype
#@todo

Returns the content subtype name as defined in [MIME-IMB].

--- media_subtype
#@todo

media_subtype is obsolete.  Use #subtype instead.

--- param
#@todo

Returns a hash that represents parameters as defined in [MIME-IMB].

--- content_id
#@todo

Returns a string giving the content id as defined in [MIME-IMB].

--- description
#@todo

Returns a string giving the content description as defined in [MIME-IMB].

--- encoding
#@todo

Returns a string giving the content transfer encoding as defined in [MIME-IMB].

--- size
#@todo

Returns a number giving the size of the body in octets.

--- md5
#@todo

Returns a string giving the body MD5 value as defined in [MD5].

--- disposition
#@todo

Returns a [[c:Net::IMAP::ContentDisposition]] object giving
the content disposition.

--- language
#@todo

Returns a string or an array of strings giving the body
language value as defined in [LANGUAGE-TAGS].

--- extension
#@todo

Returns extension data.

--- multipart?
#@todo

Returns false.



= class Net::IMAP::BodyTypeText < Struct

Net::IMAP::BodyTypeText represents TEXT body structures of messages.

== Instance Methods

--- media_type
#@todo

--- subtype
#@todo

--- media_subtype
#@todo

obsolete. use #subtype instead.

--- param
#@todo

--- content_id
#@todo

--- description
#@todo

--- encoding
#@todo

--- size
#@todo

--- lines
#@todo

Returns the size of the body in text lines.

And Net::IMAP::BodyTypeText has all methods of [[c:Net::IMAP::BodyTypeBasic]].

--- md5
#@todo

--- disposition
#@todo

--- language
#@todo

--- extension
#@todo

--- multipart?
#@todo

Returns false.



= class Net::IMAP::BodyTypeMessage < Struct

Net::IMAP::BodyTypeMessage represents MESSAGE/RFC822 body
 structures of messages.

== Instance Methods

--- media_type
#@todo

--- subtype
#@todo

--- media_subtype
#@todo

obsolete. use #subtype instead.

--- param
#@todo

--- content_id
#@todo

--- description
#@todo

--- encoding
#@todo

--- size
#@todo

--- envelope
#@todo

Returns a [[c:Net::IMAP::Envelope]] giving the envelope structure.

--- body
#@todo

Returns an object giving the body structure.

And Net::IMAP::BodyTypeMessage has all methods of [[c:Net::IMAP::BodyTypeText]].

--- lines
#@todo

Returns the size of the body in text lines.

And Net::IMAP::BodyTypeText has all methods of [[c:Net::IMAP::BodyTypeBasic]].

--- md5
#@todo

--- disposition
#@todo

--- language
#@todo

--- extension
#@todo

--- multipart?
#@todo

Returns false.



= class Net::IMAP::BodyTypeMultipart < Struct

== Instance Methods

--- media_type
#@todo

Returns the content media type name as defined in [MIME-IMB].

--- subtype
#@todo

Returns the content subtype name as defined in [MIME-IMB].

--- media_subtype
#@todo

obsolete. use #subtype instead.

--- parts
#@todo

Returns multiple parts.

--- param
#@todo

Returns a hash that represents parameters as defined in
[MIME-IMB].

--- disposition
#@todo

Returns a [[c:Net::IMAP::ContentDisposition]] object giving
the content disposition.

--- language
#@todo

Returns a string or an array of strings giving the body
language value as defined in [LANGUAGE-TAGS].

--- extension
#@todo

Returns extension data.

--- multipart?
#@todo

Returns true.


#@# internal classes:
#@# = class Net::IMAP::Atom
#@# = class Net::IMAP::Literal
#@# = class Net::IMAP::QuotedString
#@# = class Net::IMAP::MessageSet
#@# = class Net::IMAP::RawData


#@# internal classes for authentication
#@# = class Net::IMAP::LoginAuthenticator
#@# 
#@# Authenticator for the "LOGIN" authentication type.
#@# See [[m:Net::IMAP#authenticate]].
#@# 
#@# == Class Methods
#@# 
#@# --- new(user, password)
#@# #@todo
#@# 
#@# == Instance Methods
#@# 
#@# --- process(data)
#@# #@todo
#@# 
#@# 
#@# 
#@# = class Net::IMAP::CramMD5Authenticator
#@# 
#@# Authenticator for the "CRAM-MD5" authentication type.
#@# See [[m:Net::IMAP#authenticate]].
#@# 
#@# == Class Methods
#@# 
#@# --- new(user, password)
#@# #@todo
#@# 
#@# == Instance Methods
#@# 
#@# --- process(challenge)
#@# #@todo
#@# 
#@# 
#@# 
#@# #@since 1.9.1
#@# = class Net::IMAP::PlainAuthenticator
#@# 
#@# Authenticator for the "PLAIN" authentication type.
#@# See [[m:Net::IMAP#authenticate]].
#@# 
#@# == Class Methods
#@# 
#@# --- new(user, password)
#@# #@todo
#@# 
#@# == Instance Methods
#@# 
#@# --- process(data)
#@# #@todo
#@# 
#@# 
#@# 
#@# = class Net::IMAP::DigestMD5Authenticator
#@# 
#@# Authenticator for the "DIGEST-MD5" authentication type.
#@# See [[m:Net::IMAP#authenticate]].
#@# 
#@# == Class Methods
#@# 
#@# --- new(user, password, authname = nil)
#@# #@todo
#@# 
#@# == Instance Methods
#@# 
#@# --- process(challenge)
#@# #@todo
#@# #@end



= class Net::IMAP::Error < StandardError

すべての IMAP 例外クラスのスーパークラス。

= class Net::IMAP::DataFormatError < Net::IMAP::Error

データフォーマットが正しくない場合に発生する例外のクラスです。

= class Net::IMAP::ResponseParseError < Net::IMAP::Error

サーバからのレスポンスが正しくパースできない場合に発生する
例外のクラスです。

= class Net::IMAP::ResponseError < Net::IMAP::Error

サーバからのレスポンスがエラーを示している場合に発生する例外
のクラスです。

実際にはこれを継承した
  * [[c:Net::IMAP::NoResponseError]]
  * [[c:Net::IMAP::BadResponseError]]
  * [[c:Net::IMAP::ByeResponseError]]
これらのクラスの例外が発生します。

= class Net::IMAP::NoResponseError < Net::IMAP::ResponseError

サーバから "NO" レスポンスが来た場合に発生する例外のクラスです。
コマンドが正常に完了しなかった場合に発生します。

= class Net::IMAP::BadResponseError < Net::IMAP::ResponseError

サーバから "BAD" レスポンスが来た場合に発生する例外のクラスです。
クライアントからのコマンドが IMAP の規格から外れている場合や
サーバ内部エラーの場合に発生します。

= class Net::IMAP::ByeResponseError < Net::IMAP::ResponseError

サーバから "BYE" レスポンスが来た場合に発生する例外のクラスです。
ログインが拒否された場合や、クライアントが無反応で
タイムアウトした場合に発生します。

#@since 1.9.1
= class Net::IMAP::FlagCountError < Net::IMAP::Error

サーバからのレスポンスに含まれるフラグが多すぎるときに発生する例外です。

この上限は [[m:Net::IMAP#max_flag_count=]] で設定します。

#@end
