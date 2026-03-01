-- luci-app-openclaw — 基本设置 CBI Model
local sys = require "luci.sys"

m = Map("openclaw", "OpenClaw AI 网关",
	"OpenClaw 是一个 AI 编程代理网关，支持 GitHub Copilot、Claude、GPT、Gemini 等大模型以及 Telegram、Discord 等多种消息渠道。")

-- 隐藏底部的「保存并应用」「保存」「复位」按钮 (本页无可编辑的 UCI 选项)
m.submit = false
m.reset = false

-- ═══════════════════════════════════════════
-- 状态面板
-- ═══════════════════════════════════════════
m:section(SimpleSection).template = "openclaw/status"

-- ═══════════════════════════════════════════
-- 快捷操作
-- ═══════════════════════════════════════════
s3 = m:section(SimpleSection, nil, "快捷操作")
s3.template = "cbi/nullsection"

act = s3:option(DummyValue, "_actions")
act.rawhtml = true
act.cfgvalue = function(self, section)
	local ctl_url = luci.dispatcher.build_url("admin", "services", "openclaw", "service_ctl")
	local log_url = luci.dispatcher.build_url("admin", "services", "openclaw", "setup_log")
	local check_url = luci.dispatcher.build_url("admin", "services", "openclaw", "check_update")
	local update_url = luci.dispatcher.build_url("admin", "services", "openclaw", "do_update")
	local uninstall_url = luci.dispatcher.build_url("admin", "services", "openclaw", "uninstall")
	local html = {}

	-- 按钮区域
	html[#html+1] = '<div style="display:flex;gap:10px;flex-wrap:wrap;margin:10px 0;">'
	html[#html+1] = '<button class="btn cbi-button cbi-button-apply" type="button" onclick="ocSetup()" id="btn-setup" title="下载 Node.js 并安装 OpenClaw">🚀 安装运行环境</button>'
	html[#html+1] = '<button class="btn cbi-button cbi-button-action" type="button" onclick="ocServiceCtl(\'restart\')">🔄 重启服务</button>'
	html[#html+1] = '<button class="btn cbi-button cbi-button-action" type="button" onclick="ocServiceCtl(\'stop\')">⏹️ 停止服务</button>'
	html[#html+1] = '<button class="btn cbi-button cbi-button-action" type="button" onclick="ocCheckUpdate()" id="btn-check-update">🔍 检测升级</button>'
	html[#html+1] = '<button class="btn cbi-button cbi-button-remove" type="button" onclick="ocUninstall()" id="btn-uninstall" title="删除 Node.js、OpenClaw 运行环境及相关数据">🗑️ 卸载环境</button>'
	html[#html+1] = '</div>'
	html[#html+1] = '<div id="action-result" style="margin-top:8px;"></div>'
	html[#html+1] = '<div id="oc-update-action" style="margin-top:8px;display:none;"></div>'

	-- 安装日志面板 (默认隐藏)
	html[#html+1] = '<div id="setup-log-panel" style="display:none;margin-top:12px;">'
	html[#html+1] = '<div style="display:flex;align-items:center;justify-content:space-between;margin-bottom:6px;">'
	html[#html+1] = '<span id="setup-log-title" style="font-weight:600;font-size:14px;">📋 安装日志</span>'
	html[#html+1] = '<span id="setup-log-status" style="font-size:12px;color:#999;"></span>'
	html[#html+1] = '</div>'
	html[#html+1] = '<pre id="setup-log-content" style="background:#1a1b26;color:#a9b1d6;padding:14px 16px;border-radius:6px;font-size:12px;line-height:1.6;max-height:400px;overflow-y:auto;white-space:pre-wrap;word-break:break-all;border:1px solid #2d333b;margin:0;"></pre>'
	html[#html+1] = '<div id="setup-log-result" style="margin-top:10px;display:none;"></div>'
	html[#html+1] = '</div>'

	-- JavaScript
	html[#html+1] = '<script type="text/javascript">'

	-- 安装运行环境 (带实时日志)
	html[#html+1] = 'var _setupTimer=null;'
	html[#html+1] = 'function ocSetup(){'
	html[#html+1] = 'var btn=document.getElementById("btn-setup");'
	html[#html+1] = 'var panel=document.getElementById("setup-log-panel");'
	html[#html+1] = 'var logEl=document.getElementById("setup-log-content");'
	html[#html+1] = 'var titleEl=document.getElementById("setup-log-title");'
	html[#html+1] = 'var statusEl=document.getElementById("setup-log-status");'
	html[#html+1] = 'var resultEl=document.getElementById("setup-log-result");'
	html[#html+1] = 'var actionEl=document.getElementById("action-result");'
	html[#html+1] = 'btn.disabled=true;btn.textContent="⏳ 安装中...";'
	html[#html+1] = 'actionEl.textContent="";'
	html[#html+1] = 'panel.style.display="block";'
	html[#html+1] = 'logEl.textContent="正在启动安装...\\n";'
	html[#html+1] = 'titleEl.textContent="📋 安装日志";'
	html[#html+1] = 'statusEl.innerHTML="<span style=\\"color:#7aa2f7;\\">⏳ 安装进行中...</span>";'
	html[#html+1] = 'resultEl.style.display="none";'
	html[#html+1] = '(new XHR()).get("' .. ctl_url .. '?action=setup",null,function(x){'
	html[#html+1] = 'try{JSON.parse(x.responseText);}catch(e){}'
	html[#html+1] = 'ocPollSetupLog();'
	html[#html+1] = '});'
	html[#html+1] = '}'

	-- 轮询安装日志
	html[#html+1] = 'function ocPollSetupLog(){'
	html[#html+1] = 'if(_setupTimer)clearInterval(_setupTimer);'
	html[#html+1] = '_setupTimer=setInterval(function(){'
	html[#html+1] = '(new XHR()).get("' .. log_url .. '",null,function(x){'
	html[#html+1] = 'try{'
	html[#html+1] = 'var r=JSON.parse(x.responseText);'
	html[#html+1] = 'var logEl=document.getElementById("setup-log-content");'
	html[#html+1] = 'var statusEl=document.getElementById("setup-log-status");'
	html[#html+1] = 'if(r.log)logEl.textContent=r.log;'
	html[#html+1] = 'logEl.scrollTop=logEl.scrollHeight;'
	html[#html+1] = 'if(r.state==="running"){'
	html[#html+1] = 'statusEl.innerHTML="<span style=\\"color:#7aa2f7;\\">⏳ 安装进行中...</span>";'
	html[#html+1] = '}else if(r.state==="success"){'
	html[#html+1] = 'clearInterval(_setupTimer);_setupTimer=null;'
	html[#html+1] = 'ocSetupDone(true,r.log);'
	html[#html+1] = '}else if(r.state==="failed"){'
	html[#html+1] = 'clearInterval(_setupTimer);_setupTimer=null;'
	html[#html+1] = 'ocSetupDone(false,r.log);'
	html[#html+1] = '}'
	html[#html+1] = '}catch(e){}'
	html[#html+1] = '});'
	html[#html+1] = '},1500);'
	html[#html+1] = '}'

	-- 安装完成处理
	html[#html+1] = 'function ocSetupDone(ok,log){'
	html[#html+1] = 'var btn=document.getElementById("btn-setup");'
	html[#html+1] = 'var statusEl=document.getElementById("setup-log-status");'
	html[#html+1] = 'var resultEl=document.getElementById("setup-log-result");'
	html[#html+1] = 'btn.disabled=false;btn.textContent="🚀 安装运行环境";'
	html[#html+1] = 'resultEl.style.display="block";'
	html[#html+1] = 'if(ok){'
	html[#html+1] = 'statusEl.innerHTML="<span style=\\"color:#1a7f37;\\">✅ 安装完成</span>";'
	html[#html+1] = 'resultEl.innerHTML="<div style=\\"border:1px solid #c6e9c9;background:#e6f7e9;padding:12px 16px;border-radius:6px;\\">"+'
	html[#html+1] = '"<strong style=\\"color:#1a7f37;font-size:14px;\\">🎉 恭喜！OpenClaw 运行环境安装成功！</strong><br/>"+'
	html[#html+1] = '"<span style=\\"color:#555;font-size:13px;line-height:1.8;\\">服务已自动启用并启动，点击下方按钮刷新页面查看运行状态。</span><br/>"+'
	html[#html+1] = '"<button class=\\"btn cbi-button cbi-button-apply\\" type=\\"button\\" onclick=\\"location.reload()\\" style=\\"margin-top:10px;\\">🔄 刷新页面</button></div>";'
	html[#html+1] = '}else{'
	html[#html+1] = 'statusEl.innerHTML="<span style=\\"color:#cf222e;\\">❌ 安装失败</span>";'
	-- 分析失败原因
	html[#html+1] = 'var reasons=ocAnalyzeFailure(log);'
	html[#html+1] = 'resultEl.innerHTML="<div style=\\"border:1px solid #f5c6cb;background:#ffeef0;padding:12px 16px;border-radius:6px;\\">"+'
	html[#html+1] = '"<strong style=\\"color:#cf222e;font-size:14px;\\">❌ 安装失败</strong><br/>"+'
	html[#html+1] = '"<div style=\\"margin:8px 0;padding:10px 14px;background:#fff5f5;border-radius:4px;font-size:13px;line-height:1.8;\\">"+'
	html[#html+1] = '"<strong>🔍 可能的失败原因：</strong><br/>"+reasons+"</div>"+'
	html[#html+1] = '"<div style=\\"margin-top:8px;font-size:12px;color:#666;\\">💡 完整日志见上方终端输出，也可在终端查看：<code>cat /tmp/openclaw-setup.log</code></div></div>";'
	html[#html+1] = '}'
	html[#html+1] = '}'

	-- 分析失败原因
	html[#html+1] = 'function ocAnalyzeFailure(log){'
	html[#html+1] = 'var reasons=[];'
	html[#html+1] = 'if(!log)return"未知错误，请检查日志。";'
	html[#html+1] = 'var ll=log.toLowerCase();'
	-- 网络问题
	html[#html+1] = 'if(ll.indexOf("could not resolve")>=0||ll.indexOf("connection timed out")>=0||ll.indexOf("curl")>=0&&ll.indexOf("fail")>=0||ll.indexOf("wget")>=0&&ll.indexOf("fail")>=0||ll.indexOf("所有镜像均下载失败")>=0){'
	html[#html+1] = 'reasons.push("🌐 <b>网络连接失败</b> — 无法下载 Node.js。请检查路由器是否能访问外网。<br/>&nbsp;&nbsp;💡 解决: 检查 DNS 设置和网络连接，或手动指定镜像: <code>NODE_MIRROR=https://npmmirror.com/mirrors/node openclaw-env setup</code>");'
	html[#html+1] = '}'
	-- 磁盘空间
	html[#html+1] = 'if(ll.indexOf("no space")>=0||ll.indexOf("disk full")>=0||ll.indexOf("enospc")>=0){'
	html[#html+1] = 'reasons.push("💾 <b>磁盘空间不足</b> — Node.js + OpenClaw 需要约 200MB 空间。<br/>&nbsp;&nbsp;💡 解决: 运行 <code>df -h</code> 检查可用空间，清理不需要的文件或使用外部存储。");'
	html[#html+1] = '}'
	-- 架构不支持
	html[#html+1] = 'if(ll.indexOf("不支持的 cpu 架构")>=0||ll.indexOf("不支持的架构")>=0){'
	html[#html+1] = 'reasons.push("🔧 <b>CPU 架构不支持</b> — 仅支持 x86_64 和 aarch64 (ARM64)。<br/>&nbsp;&nbsp;💡 当前设备架构可能是 32 位 ARM 或 MIPS，无法运行 Node.js 22。");'
	html[#html+1] = '}'
	-- npm 安装失败
	html[#html+1] = 'if(ll.indexOf("npm err")>=0||ll.indexOf("npm warn")>=0&&ll.indexOf("openclaw 安装验证失败")>=0){'
	html[#html+1] = 'reasons.push("📦 <b>npm 安装 OpenClaw 失败</b> — npm 包下载或安装出错。<br/>&nbsp;&nbsp;💡 解决: 尝试手动安装 <code>PATH=/opt/openclaw/node/bin:$PATH npm install -g openclaw@latest --prefix=/opt/openclaw/global</code>");'
	html[#html+1] = '}'
	-- 权限问题
	html[#html+1] = 'if(ll.indexOf("permission denied")>=0||ll.indexOf("eacces")>=0){'
	html[#html+1] = 'reasons.push("🔒 <b>权限不足</b> — 文件或目录权限问题。<br/>&nbsp;&nbsp;💡 解决: 运行 <code>chown -R openclaw:openclaw /opt/openclaw</code> 或以 root 用户重试。");'
	html[#html+1] = '}'
	-- tar 解压失败
	html[#html+1] = 'if(ll.indexOf("tar")>=0&&(ll.indexOf("error")>=0||ll.indexOf("fail")>=0)){'
	html[#html+1] = 'reasons.push("📂 <b>解压失败</b> — Node.js 安装包可能下载不完整。<br/>&nbsp;&nbsp;💡 解决: 删除缓存重试 <code>rm -rf /opt/openclaw/node && openclaw-env setup</code>");'
	html[#html+1] = '}'
	-- 验证失败
	html[#html+1] = 'if(ll.indexOf("安装验证失败")>=0){'
	html[#html+1] = 'reasons.push("⚠️ <b>安装验证失败</b> — 程序已下载但无法正常运行。<br/>&nbsp;&nbsp;💡 可能是 glibc/musl 不兼容，请确认系统 C 库类型: <code>ldd --version 2>&1 | head -1</code>");'
	html[#html+1] = '}'
	-- 兜底
	html[#html+1] = 'if(reasons.length===0){'
	html[#html+1] = 'reasons.push("⚠️ <b>未识别的错误</b> — 请查看上方完整日志分析具体原因。<br/>&nbsp;&nbsp;💡 您也可以尝试手动执行: <code>openclaw-env setup</code> 查看详细输出。");'
	html[#html+1] = '}'
	html[#html+1] = 'return reasons.join("<br/><br/>");'
	html[#html+1] = '}'

	-- 普通服务操作 (restart/stop)
	html[#html+1] = 'function ocServiceCtl(action){'
	html[#html+1] = 'var el=document.getElementById("action-result");'
	html[#html+1] = 'el.innerHTML="<span style=\\"color:#999\\">⏳ 正在执行...</span>";'
	html[#html+1] = '(new XHR()).get("' .. ctl_url .. '?action="+action,null,function(x){'
	html[#html+1] = 'try{var r=JSON.parse(x.responseText);'
	html[#html+1] = 'if(r.status==="ok"){el.innerHTML="<span style=\\"color:green\\">✅ "+action+" 已完成</span>";}'
	html[#html+1] = 'else{el.innerHTML="<span style=\\"color:red\\">❌ "+(r.message||"失败")+"</span>";}'
	html[#html+1] = '}catch(e){el.innerHTML="<span style=\\"color:red\\">❌ 错误</span>";}'
	html[#html+1] = '});}'

	-- 检测升级
	html[#html+1] = 'function ocCheckUpdate(){'
	html[#html+1] = 'var btn=document.getElementById("btn-check-update");'
	html[#html+1] = 'var el=document.getElementById("action-result");'
	html[#html+1] = 'var act=document.getElementById("oc-update-action");'
	html[#html+1] = 'btn.disabled=true;btn.textContent="⏳ 正在检测...";el.textContent="";act.style.display="none";'
	html[#html+1] = '(new XHR()).get("' .. check_url .. '",null,function(x){'
	html[#html+1] = 'btn.disabled=false;btn.textContent="🔍 检测升级";'
	html[#html+1] = 'try{var r=JSON.parse(x.responseText);'
	html[#html+1] = 'if(!r.current){el.innerHTML="<span style=\\"color:#999\\">⚠️ OpenClaw 未安装</span>";return;}'
	html[#html+1] = 'if(r.has_update){'
	html[#html+1] = 'el.innerHTML="<span style=\\"color:#e36209\\">📦 当前: v"+r.current+" → 最新: v"+r.latest+"</span>";'
	html[#html+1] = 'act.style.display="block";'
	html[#html+1] = 'act.innerHTML=\'<button class="btn cbi-button cbi-button-apply" type="button" onclick="ocDoUpdate()" id="btn-do-update">⬆️ 立即升级</button> <span id="upgrade-status" style="margin-left:10px;font-size:13px;"></span>\';'
	html[#html+1] = '}else{'
	html[#html+1] = 'el.innerHTML="<span style=\\"color:green\\">✅ 已是最新版本 (v"+r.current+")</span>";'
	html[#html+1] = '}'
	html[#html+1] = '}catch(e){el.innerHTML="<span style=\\"color:red\\">❌ 检测失败</span>";}'
	html[#html+1] = '});}'

	-- 执行升级
	html[#html+1] = 'function ocDoUpdate(){'
	html[#html+1] = 'var btn=document.getElementById("btn-do-update");'
	html[#html+1] = 'var st=document.getElementById("upgrade-status");'
	html[#html+1] = 'if(!confirm("确定要升级 OpenClaw？升级期间服务将短暂中断。"))return;'
	html[#html+1] = 'btn.disabled=true;btn.textContent="⏳ 正在升级...";'
	html[#html+1] = 'st.innerHTML="<span style=\\"color:#999\\">升级可能需要几分钟，请耐心等待...</span>";'
	html[#html+1] = '(new XHR()).get("' .. update_url .. '",null,function(x){'
	html[#html+1] = 'try{var r=JSON.parse(x.responseText);'
	html[#html+1] = 'if(r.status==="ok"){'
	html[#html+1] = 'btn.textContent="✅ 升级已启动";'
	html[#html+1] = 'st.innerHTML="<span style=\\"color:green\\">"+r.message+"</span>"+'
	html[#html+1] = '"<br/><button class=\\"btn cbi-button cbi-button-action\\" type=\\"button\\" onclick=\\"ocServiceCtl(\'restart\')\\" style=\\"margin-top:8px;\\">🔄 重启服务</button>";'
	html[#html+1] = '}else{btn.disabled=false;btn.textContent="⬆️ 立即升级";st.innerHTML="<span style=\\"color:red\\">❌ "+r.message+"</span>";}'
	html[#html+1] = '}catch(e){btn.disabled=false;btn.textContent="⬆️ 立即升级";st.innerHTML="<span style=\\"color:red\\">❌ 请求失败</span>";}'
	html[#html+1] = '});}'

	-- 卸载运行环境
	html[#html+1] = 'function ocUninstall(){'
	html[#html+1] = 'if(!confirm("确定要卸载 OpenClaw 运行环境？\\n\\n将删除 Node.js、OpenClaw 程序及配置数据（/opt/openclaw 目录），服务将停止运行。\\n\\n插件本身不会被删除，之后可重新安装运行环境。"))return;'
	html[#html+1] = 'var btn=document.getElementById("btn-uninstall");'
	html[#html+1] = 'var el=document.getElementById("action-result");'
	html[#html+1] = 'btn.disabled=true;btn.textContent="⏳ 正在卸载...";'
	html[#html+1] = 'el.innerHTML="<span style=\\"color:#999\\">正在停止服务并清理文件...</span>";'
	html[#html+1] = '(new XHR()).get("' .. uninstall_url .. '",null,function(x){'
	html[#html+1] = 'btn.disabled=false;btn.textContent="🗑️ 卸载环境";'
	html[#html+1] = 'try{var r=JSON.parse(x.responseText);'
	html[#html+1] = 'if(r.status==="ok"){'
	html[#html+1] = 'el.innerHTML="<div style=\\"border:1px solid #d0d7de;background:#f6f8fa;padding:12px 16px;border-radius:6px;\\">"+'
	html[#html+1] = '"<strong style=\\"color:#1a7f37;\\">✅ 卸载完成</strong><br/>"+'
	html[#html+1] = '"<span style=\\"color:#555;font-size:13px;\\">"+r.message+"</span><br/>"+'
	html[#html+1] = '"<button class=\\"btn cbi-button cbi-button-apply\\" type=\\"button\\" onclick=\\"location.reload()\\" style=\\"margin-top:8px;\\">🔄 刷新页面</button></div>";'
	html[#html+1] = '}else{el.innerHTML="<span style=\\"color:red\\">❌ "+(r.message||"卸载失败")+"</span>";}'
	html[#html+1] = '}catch(e){el.innerHTML="<span style=\\"color:red\\">❌ 请求失败</span>";}'
	html[#html+1] = '});}'

	html[#html+1] = '</script>'
	return table.concat(html, "\n")
end

-- ═══════════════════════════════════════════
-- 使用指南
-- ═══════════════════════════════════════════
s4 = m:section(SimpleSection, nil)
s4.template = "cbi/nullsection"
guide = s4:option(DummyValue, "_guide")
guide.rawhtml = true
guide.cfgvalue = function()
	local html = {}
	html[#html+1] = '<div style="border:1px solid #d0e8ff;background:#f0f7ff;padding:14px 18px;border-radius:6px;margin-top:12px;line-height:1.8;font-size:13px;">'
	html[#html+1] = '<strong style="font-size:14px;">📖 使用指南</strong><br/>'
	html[#html+1] = '<span style="color:#555;">'
	html[#html+1] = '① 首次使用请点击 <b>「安装运行环境」</b>，安装完成后服务会自动启动<br/>'
	html[#html+1] = '② 进入 <b>「Web 控制台」</b> 配置 AI 模型、消息渠道，直接开始对话<br/>'
	html[#html+1] = '③ 进入 <b>「配置管理」</b> 可使用交互式向导进行高级配置</span>'
	html[#html+1] = '<div style="margin-top:10px;padding-top:10px;border-top:1px solid #d0e8ff;">'
	html[#html+1] = '<span style="color:#888;">有疑问？请关注B站并留言：</span>'
	html[#html+1] = '<a href="https://space.bilibili.com/59438380" target="_blank" rel="noopener" style="color:#00a1d6;font-weight:bold;text-decoration:none;">'
	html[#html+1] = '🔗 space.bilibili.com/59438380</a>'
	html[#html+1] = '<span style="margin-left:16px;color:#888;">GitHub 项目：</span>'
	html[#html+1] = '<a href="https://github.com/10000ge10000/luci-app-openclaw" target="_blank" rel="noopener" style="color:#24292f;font-weight:bold;text-decoration:none;">'
	html[#html+1] = '🐙 10000ge10000/luci-app-openclaw</a></div></div>'
	return table.concat(html, "\n")
end

return m
