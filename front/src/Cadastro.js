import { useState } from "react";
import { useNavigate, Link } from "react-router-dom";
import "./Login.css"; 
import { useCookies } from 'react-cookie';



async function jsonPost(url, body) {
  const res = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body || {}),
  });
  const text = await res.text();
  let data = null;
  try { data = text ? JSON.parse(text) : null; } catch { data = { raw: text }; }
  if (!res.ok) throw new Error(`HTTP ${res.status}: ${text}`);
  return data;
}

export default function Cadastro() {
  const [name, setName] = useState("");
  const [emailReg, setEmailReg] = useState("");
  const [passReg, setPassReg] = useState("");
  const [passReg2, setPassReg2] = useState("");
  const [ok, setOk] = useState("");
  const [err, setErr] = useState("");
  const [token, setToken] = useState("");
  const [cookies, setCookie, removeCookie] = useCookies(['nomeDoCookie']);

  const navigate = useNavigate();

  async function doRegister() {
    if(passReg === passReg2){
      console.log("oi");
    fetch("/grpc/user", {
  method: "POST",
  headers: { "Content-Type": "application/json" },
  body: JSON.stringify({
    nome: name,
    login: emailReg,
    senha: passReg,
    score: 0
  }),
})
  .then((res) => {
    if (!res.ok) {
      throw new Error(`HTTP ${res.status}`);
    }
    return res.text(); // ← mudei para .text() para testar o que o servidor devolve
  })
  .then((data) => {
    console.log("Resposta do servidor:", data);
    try {
      const json = JSON.parse(data);
      console.log("JSON parseado:", json);
      setToken(json.rememberTokenRes || "");
      setOk("Usuário cadastrado com sucesso!");
      setErr("");
      setCookie('token', json.rememberTokenRes, { path: '/' });
      setTimeout(() => navigate("/quiz", { replace: true }), 1000);
    } catch {
      console.error("Resposta não é JSON válido.");
    }
  })
  .catch((err) => console.error("Erro:", err));

    }else{
      console.log("senha diferente");
    }
  }

  return (
    <div className="login-wrap">
      <form className="cadastro-card" onSubmit={(e) => {e.preventDefault()}}>
        <h1 className="login-title">Criar uma conta</h1>
        <p className="texto-inicial">Preencha os dados para começar o Quiz.</p>

        <label className="login-label">Nome</label>
        <input
          className="login-input"
          placeholder="Seu nome"
          value={name}
          onChange={(e) => setName(e.target.value)}
        />

        <label className="login-label">Email</label>
        <input
          className="login-input"
          placeholder="seu@email"
          value={emailReg}
          onChange={(e) => setEmailReg(e.target.value)}
        />

        <label className="login-label">Senha</label>
        <input
          className="login-input"
          type="password"
          placeholder="crie uma senha"
          value={passReg}
          onChange={(e) => setPassReg(e.target.value)}
        />

        <label className="login-label">Confirmar senha</label>
        <input
          className="login-input"
          type="password"
          placeholder="repita a senha"
          value={passReg2}
          onChange={(e) => setPassReg2(e.target.value)}
        />

        
        <div className="btn-row">
          <button className="btn-login" type="button" onClick={() => doRegister()}>
            Criar conta
          </button>
        </div>

        {ok ? <p className="msg ok">{ok}</p> : null}
        {err ? <p className="msg err">{err}</p> : null}

        <div className="login-links2">
          Já possui conta?{" "}
          <Link to="/login" style={{ textDecoration: "underline", color: "#fff" }}>
            Fazer login
          </Link>
        </div>
      </form>
    </div>
  );
}
