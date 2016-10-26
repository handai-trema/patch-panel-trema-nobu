# 課題内容
1.ポートのミラーリング
指定したポート群から入ってくるパケットを，予め指定されたマネージメントポートへ転送する．そのためのサブコマンドをつくる．
2.パッチとミラーリングの一覧
設定したパッチの組み合わせと，ミラーリングするポートの一覧を表示するサブコマンドをつくる．

# 解答
## プログラム
* [プログラムリンク](https://github.com/handai-trema/patch-panel-trema-nobu/blob/develop/lib/mirror_patch_panel.rb)

## 片方向のパケット転送ルール設定
まず，ミラーリングでは片方向（ミラーリングポートからマネージメントポート）の通信しか必要がないので，片方向のパケット転送ルールを設定するメソッドを記述する．

```ruby
  def add_flow_entries_oneway(dpid,port_a,port_b)
    send_flow_mod_add(dpid,
                      match: Match.new(in_port: port_a),
                      actions: SendOutPort.new(port_b))
  end
```

純粋に，send_flow_mod_addを，ポートaからのパケットのみに対してpacket_outを行い，ポートbへ転送するようにする．

## 片方向のパケット転送ルール解除
先程と同様に，ルールを削除するメソッドを記述する．

```ruby
  def delete_flow_entries_oneway(dpid,port)
    send_flow_mod_delete(dpid,
			match:Match.new(in_port: port))
  end
```

## ミラーリングするポートの設定
ミラーリングにおいては，指定したポートからマネージメントポートへのパケット転送を設定するが．事前にパッチパネルの設定がされている場合，考慮して宛先を２つにすることとする．

```ruby
  def create_mirror(dpid,port)
      @mirrored_port[dpid]+=port
      @patch[dpid].each do |port_a,port_b|
        if(port_a == port) then
	  delete_flow_entries_oneway dpid,port
	  add_flow_entries_oneway dpid,port,[port_b,mirrorport]
	else if(port_b == port) then
	  delete_flow_entries_oneway dpid,port
	  add_flow_entries_oneway dpid,port,[port_a,mirrorport]
	else
	  add_flow_entries_oneway dpid,port,mirrorport
	end
      end
  end
```

実装では，パッチパネルの配列それぞれについてループで処理をし，もしミラーリングポートにしたいポートとかぶっていた場合は一度ルールを消去し，もとからある転送先ポートとマネージメントポートを宛先とする．パッチパネルに含まれていない場合は，削除せずにルールを追加する．

## ミラーリングするポートの解除
同じくミラーリングポートの解除を行うには，まずそのポートからの転送ルールを一度削除する．
もしpatchにそのポートが含まれている場合は，もとからあるデータをもとに転送先を指定する．

```ruby
def delete_mirror(dpid,port)
    @mirrored_port[dpid]-=port
    @patch[dpid].each do |port_a,port_b|
    delete_flow_entries_oneway dpid,port
    if (port_a==port) then
      add_flow_entries_oneway dpid,port,port_b
    else if (port_b==port) then
      add_flow_entries_oneway dpid,port,port_a
    end
    end
  end
 
```
## パッチパネル設定一覧の表示
パッチパネルの設定の一覧を表示するには，@patch[dpid]配列のすべてのポートの組み合わせをeach文によって表示する．

```ruby
  def show_patches(dpid)
    logger.info "patches list"
    @patch[dpid].each do |port_a,port_b|
    	logger.info port_a+' '+port_b
    end
  end
```

## ミラーリングポート一覧の表示
ミラーリングの設定の一覧を表示するには，@mirrored_port[dpid]という，ミラーリングポートを格納する配列の中身をeach文によってそれぞれ表示する．


```ruby
  def show_mirrors(dpid)
    logger.info "mirrored port list"
    @mirrored_port[dpid].each do |port|
      logger.info port
    end
  end
```

# bin/patch_panelの設定
ここに指定の記述を行うことで，tremaコマンドのサブコマンドとして，libで記述した関数を実行することができる．
引数や関数名を合わせて記述したのが次のプログラムである．

```ruby
  desc 'Creates a new mirror'
  arg_name 'dpid port'
  command :create do |c|
    c.desc 'Location to find socket files'
    c.flag [:S, :socket_dir], default_value: Trema::DEFAULT_SOCKET_DIR

    c.action do |_global_options, options, args|
      dpid = args[0].hex
      port = args[1].to_i
      Trema.trema_process('PatchPanel', options[:socket_dir]).controller.
        create_mirror(dpid, port)
    end
  end

  desc 'Deletes a mirror'
  arg_name 'dpid port'
  command :delete do |c|
    c.desc 'Location to find socket files'
    c.flag [:S, :socket_dir], default_value: Trema::DEFAULT_SOCKET_DIR

    c.action do |_global_options, options, args|
      dpid = args[0].hex
      port = args[1].to_i
      Trema.trema_process('PatchPanel', options[:socket_dir]).controller.
        delete_mirror(dpid, port)
    end
  end

  desc 'show mirror'
  arg_name 'dpid'
  command :delete do |c|
    c.desc 'Location to find socket files'
    c.flag [:S, :socket_dir], default_value: Trema::DEFAULT_SOCKET_DIR

    c.action do |_global_options, options, args|
      dpid = args[0].hex
      Trema.trema_process('PatchPanel', options[:socket_dir]).controller.
        show_mirrors(dpid)
    end
  end


  desc 'show patche'
  arg_name 'dpid'
  command :delete do |c|
    c.desc 'Location to find socket files'
    c.flag [:S, :socket_dir], default_value: Trema::DEFAULT_SOCKET_DIR

    c.action do |_global_options, options, args|
      dpid = args[0].hex
```
