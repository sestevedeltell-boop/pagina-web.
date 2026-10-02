// Genera dist/instalar_en_studio.lua: un unico script para pegar en la Barra de comandos de Studio
// que crea todos los scripts del proyecto en su sitio (equivale a sincronizar con Rojo).
//   node tools/build_installer.js
const fs = require("fs");
const path = require("path");

const root = path.join(__dirname, "..");
// carpeta del repo -> [servicio, ruta de carpetas dentro del servicio]
const MAP = {
  "src/shared": ["ReplicatedStorage", ["IslasShared"]],
  "src/maps": ["ServerStorage", ["IslasMapas"]],
  "src/server": ["ServerScriptService", ["IslasServer"]],
  "src/client": ["StarterPlayerScripts", ["IslasClient"]],
};

const entries = [];
for (const [dir, [service, base]] of Object.entries(MAP)) {
  (function walk(d, rel) {
    for (const f of fs.readdirSync(path.join(root, d), { withFileTypes: true }).sort((a, b) => a.name.localeCompare(b.name))) {
      if (f.isDirectory()) walk(path.join(d, f.name), [...rel, f.name]);
      else if (f.name.endsWith(".lua")) {
        let name = f.name.replace(/\.lua$/, "");
        let cls = "ModuleScript";
        if (name.endsWith(".server")) { name = name.slice(0, -7); cls = "Script"; }
        else if (name.endsWith(".client")) { name = name.slice(0, -7); cls = "LocalScript"; }
        entries.push({ service, path: [...base, ...rel], name, cls, source: fs.readFileSync(path.join(root, d, f.name), "utf8") });
      }
    }
  })(dir, []);
}

function bracket(src) {
  for (let n = 0; n < 10; n++) {
    const close = "]" + "=".repeat(n) + "]";
    if (!src.includes(close)) return ["[" + "=".repeat(n) + "[", close];
  }
  throw new Error("no hay nivel de corchetes libre");
}

let out = `-- INSTALADOR de Islas de Desastres.
-- Pegalo en la Barra de comandos de Studio (pestana Ver > Barra de comandos) y pulsa Enter.
-- Crea (o reemplaza) estas carpetas: ReplicatedStorage.IslasShared, ServerStorage.IslasMapas,
-- ServerScriptService.IslasServer y StarterPlayer.StarterPlayerScripts.IslasClient.
-- No toca nada de tu juego salvo esas 4 carpetas.

local services = {
	ReplicatedStorage = game:GetService("ReplicatedStorage"),
	ServerStorage = game:GetService("ServerStorage"),
	ServerScriptService = game:GetService("ServerScriptService"),
	StarterPlayerScripts = game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"),
}

-- borra las carpetas raiz antiguas para reinstalar limpio
for _, pair in ipairs({
	{ "ReplicatedStorage", "IslasShared" },
	{ "ServerStorage", "IslasMapas" },
	{ "ServerScriptService", "IslasServer" },
	{ "StarterPlayerScripts", "IslasClient" },
}) do
	local old = services[pair[1]]:FindFirstChild(pair[2])
	if old then
		old:Destroy()
	end
end

local function folderAt(service, path)
	local parent = services[service]
	for _, name in ipairs(path) do
		local f = parent:FindFirstChild(name)
		if not f then
			f = Instance.new("Folder")
			f.Name = name
			f.Parent = parent
		end
		parent = f
	end
	return parent
end

local function add(service, path, name, className, source)
	local inst = Instance.new(className)
	inst.Name = name
	inst.Source = source
	inst.Parent = folderAt(service, path)
end

`;
for (const e of entries) {
  const [open, close] = bracket(e.source);
  const pathLua = "{ " + e.path.map((p) => JSON.stringify(p)).join(", ") + " }";
  out += `add(${JSON.stringify(e.service)}, ${pathLua}, ${JSON.stringify(e.name)}, ${JSON.stringify(e.cls)}, ${open}\n${e.source}${close})\n\n`;
}
out += `print("Islas de Desastres instalado: ${entries.length} scripts. Dale a Play para probar.")\n`;
fs.mkdirSync(path.join(root, "dist"), { recursive: true });
fs.writeFileSync(path.join(root, "dist", "instalar_en_studio.lua"), out);
console.log(`dist/instalar_en_studio.lua: ${entries.length} scripts, ${(out.length / 1024).toFixed(0)} KB`);
