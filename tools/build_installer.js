// Genera los instaladores para Studio a partir de src/ (equivalen a sincronizar con Rojo):
//   dist/instalar_en_studio.lua        todo en uno, para la Barra de comandos
//   dist/partes/instalar_parte_N.lua   lo mismo en trozos pequenos (pegar en orden: 1, 2, 3...)
//   dist/plugin_instalador.lua         plugin: pegalo en un Script, clic derecho > "Save as Local Plugin"
//                                      y usa el boton "Instalar Islas" de la pestana Plugins
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

const HELPERS = `local services = {
	ReplicatedStorage = game:GetService("ReplicatedStorage"),
	ServerStorage = game:GetService("ServerStorage"),
	ServerScriptService = game:GetService("ServerScriptService"),
	StarterPlayerScripts = game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"),
}

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
	local parent = folderAt(service, path)
	local old = parent:FindFirstChild(name)
	if old then
		old:Destroy()
	end
	local inst = Instance.new(className)
	inst.Name = name
	inst.Source = source
	inst.Parent = parent
end
`;

const CLEAR = `-- borra las carpetas antiguas para reinstalar limpio
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
`;

function entryCode(e) {
  const [open, close] = bracket(e.source);
  const pathLua = "{ " + e.path.map((p) => JSON.stringify(p)).join(", ") + " }";
  return `add(${JSON.stringify(e.service)}, ${pathLua}, ${JSON.stringify(e.name)}, ${JSON.stringify(e.cls)}, ${open}\n${e.source}${close})\n\n`;
}

const HEADER = `-- INSTALADOR de Islas de Desastres.
-- Crea (o reemplaza) estas carpetas: ReplicatedStorage.IslasShared, ServerStorage.IslasMapas,
-- ServerScriptService.IslasServer y StarterPlayer.StarterPlayerScripts.IslasClient.
-- No toca nada mas de tu juego.
`;

fs.mkdirSync(path.join(root, "dist", "partes"), { recursive: true });

// 1) todo en uno
let all = HEADER + "-- Pegalo en la Barra de comandos de Studio (pestana Ver > Barra de comandos) y pulsa Enter.\n\n" + HELPERS + "\n" + CLEAR + "\n";
for (const e of entries) all += entryCode(e);
all += `print("Islas de Desastres instalado: ${entries.length} scripts. Dale a Play para probar.")\n`;
fs.writeFileSync(path.join(root, "dist", "instalar_en_studio.lua"), all);

// 2) por partes (~80 KB)
for (const f of fs.readdirSync(path.join(root, "dist", "partes"))) fs.unlinkSync(path.join(root, "dist", "partes", f));
const parts = [];
let current = [];
let size = 0;
for (const e of entries) {
  const c = entryCode(e);
  if (size + c.length > 80000 && current.length > 0) {
    parts.push(current);
    current = [];
    size = 0;
  }
  current.push(c);
  size += c.length;
}
if (current.length) parts.push(current);
parts.forEach((list, i) => {
  let code = HEADER + `-- PARTE ${i + 1} DE ${parts.length}. Pega las partes en la Barra de comandos EN ORDEN (1, 2, 3...).\n\n` + HELPERS + "\n";
  if (i === 0) code += CLEAR + "\n";
  code += list.join("");
  code += `print("Islas de Desastres: parte ${i + 1} de ${parts.length} instalada${i + 1 === parts.length ? ". ¡Terminado! Dale a Play." : ""}")\n`;
  fs.writeFileSync(path.join(root, "dist", "partes", `instalar_parte_${i + 1}.lua`), code);
});

// 3) plugin con boton
let plugin = HEADER + `-- PLUGIN: pega este texto en un Script nuevo (por ejemplo en ServerStorage), clic derecho sobre el Script >
-- "Save as Local Plugin...". Despues borra ese Script y usa el boton "Instalar Islas" de la pestana Plugins.

local function install()
` + (HELPERS + "\n" + CLEAR + "\n").split("\n").map((l) => (l ? "\t" + l : l)).join("\n");
for (const e of entries) plugin += "\t" + entryCode(e).replace(/\n$/, "") + "\n";
plugin += `\tprint("Islas de Desastres instalado: ${entries.length} scripts. Dale a Play para probar.")
end

local toolbar = plugin:CreateToolbar("Islas de Desastres")
local button = toolbar:CreateButton("Instalar Islas", "Instala o actualiza los scripts de Islas de Desastres", "rbxassetid://0")
button.Click:Connect(function()
	local ok, err = pcall(install)
	if not ok then
		warn("Error instalando: " .. tostring(err))
	end
	game:GetService("ChangeHistoryService"):SetWaypoint("Instalar Islas de Desastres")
end)
`;
fs.writeFileSync(path.join(root, "dist", "plugin_instalador.lua"), plugin);

console.log(`dist/instalar_en_studio.lua: ${entries.length} scripts, ${(all.length / 1024).toFixed(0)} KB`);
console.log(`dist/partes: ${parts.length} partes`);
console.log(`dist/plugin_instalador.lua: ${(plugin.length / 1024).toFixed(0)} KB`);
