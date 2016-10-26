# Software patch-panel.
class PatchPanel < Trema::Controller
  def start(_args)
    @patch = Hash.new { [] }
    @mirrored_port = Hash.new{[]} 
        #ここに入るポートの通信はすべて特定のポートに飛ぶ
    mirrorport=100
    logger.info 'PatchPanel started.'
  end
  def create_mirror(dpid,port)
      @mirrored_port[dpid]+=port
      #もしportが@patchに含まれていたら，その情報を取得し，delete_flow_entries
      @patch[dpid].each do |port_a,port_b|
        if(port_a == port) then
	  delete_flow_entries_oneway dpid,port
	  add_flow_entries_oneway dpid,port,[port_b,mirrorport]
	else if(port_b == port) then
	  delete_flow_entries_oneway dpid,port
	  add_flow_entries_oneway dpid,port,[port_a,mirrorport]
	else
	  add_flow_entries dpid,port,mirrorport
	end
      end
  end
  def delete_mirror(dpid,port)
	#a,bのどっちかに入ってたら，port->mirrorを削除する
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
  def show_patches(dpid)
    logger.info "patches list"
    @patch[dpid].each do |port_a,port_b|
    	logger.info port_a+' '+port_b
    end
  end
  def show_mirrors(dpid)
    logger.info "mirrored port list"
    @mirrored_port[dpid].each do |port|
      logger.info port
    end
  end

  def switch_ready(dpid)
    @patch[dpid].each do |port_a, port_b|
      delete_flow_entries dpid, port_a, port_b
      add_flow_entries dpid, port_a, port_b
    end
  end

  def create_patch(dpid, port_a, port_b)
    #作る前に@mirroredportを確認し，入っている場合は一度消す
    @patch[dpid] += [port_a, port_b].sort
    if(@mirroredport.member(port_a) && @mirroredport.member(port_b))then
      delete_flow_entries dpid,port_a,port_b
      add_flow_entries_oneway dpid,port_a,[port_b,mirroreport]
      add_flow_entries_oneway dpid,port_b,[port_a,mirroreport]
    else if (@mirroredport.member(port_a))then
      delete_flow_entries_oneway dpid,port_a
      add_flow_entries_oneway dpid,port_a,[port_b,mirroreport]
      add_flow_entries_oneway dpid,port_b,port_a
    else if(@mirroredport.member(port_b))then
      delete_flow_entries_oneway dpid,port_b
      add_flow_entries_oneway dpid,port_b,[port_a,mirroreport]
      add_flow_entries_oneway dpid,port_a,port_b
    else
      add_flow_entries dpid,port_a.port_b
    end
  end

  def delete_patch(dpid, port_a, port_b)
    delete_flow_entries dpid, port_a, port_b
    @patch[dpid] -= [port_a, port_b].sort
    if(mirroredport.member(port_a))then
      add_flow_entries_oneway dpid,port_a,mirroreport
    else if(mirroredport.member(port_b))then
      add_flow_entries_oneway dpid,port_b,mirroreport
    end 
  end

  private

  def add_flow_entries(dpid, port_a, port_b)
    send_flow_mod_add(dpid,
                      match: Match.new(in_port: port_a),
                      actions: SendOutPort.new(port_b))
    send_flow_mod_add(dpid,
                      match: Match.new(in_port: port_b),
                      actions: SendOutPort.new(port_a))
  end
  def add_flow_entries_oneway(dpid,port_a,port_b)
    send_flow_mod_add(dpid,
                      match: Match.new(in_port: port_a),
                      actions: SendOutPort.new(port_b))
  end
  def delete_flow_entries(dpid, port_a, port_b)
    send_flow_mod_delete(dpid, match: Match.new(in_port: port_a))
    send_flow_mod_delete(dpid, match: Match.new(in_port: port_b))
  end
  def delete_flow_entries_oneway(dpid,port)
    send_flow_mod_delete(dpid,match:Match.new(in_port: port))
  end
end
