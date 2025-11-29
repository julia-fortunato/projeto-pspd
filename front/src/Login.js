import { useState } from "react";
import { useNavigate, useLocation, Link } from "react-router-dom";
import "./Login.css";
import { useCookies } from 'react-cookie';

export default function Login() {
  const [email, setEmail] = useState("");
  const [password, setPass] = useState("");
  const [ok, setOk] = useState("");
  const [err, setErr] = useState("");
  const [token, setToken] = useState("");
  const [cookies, setCookie, removeCookie] = useCookies(['nomeDoCookie']);

  const navigate = useNavigate();
  const location = useLocation();
  const next = location.state?.from?.pathname || "/quiz";

  function doLogin(mode) {
    fetch("/grpc/login", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        loginreq: email,
        senhareq: password,
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
          if (!json.tokenrem || json.tokenrem === "" || json.tokenrem === null) {
            setErr("Email e senha incorretos");
            return;
          }
          setToken(json.tokenrem || "");
          setCookie('token', json.tokenrem, { path: '/' });
        }catch{
          setErr("Resposta do servidor não é JSON válido.");
        }
      });
    setOk(`Login realizado via `);
    setTimeout(() => navigate(next, { replace: true }), 500);
  }

  return (
    <div className="login-wrap">
      <form className="login-card" onSubmit={(e) => e.preventDefault()}>
        <h1 className="login-title">Login</h1>
        <p className="texto-inicial">Digite seu email e senha para acessar o Quiz.</p>

        <label className="login-label">Email</label>
        <input
          className="login-input"
          placeholder="seu@email"
          value={email}
          onChange={(e) => setEmail(e.target.value)}
        />

        <label className="login-label">Senha</label>
        <input
          className="login-input"
          type="password"
          placeholder="sua senha"
          value={password}
          onChange={(e) => setPass(e.target.value)}
        />

        
        <div className="btn-row">
          <button className="btn-login" type="button" onClick={() => doLogin()}>
            Entrar
          </button>
        </div>

        <div className="login-links2" style={{ marginTop: 10 }}>
          Não possui uma conta?{" "}
          <Link to="/cadastro" style={{ textDecoration: "underline", color: "#fff" }}>
            Criar uma
          </Link>
        </div>

        {ok ? <p className="msg ok">{ok}</p> : null}
        {err ? <p className="msg err">{err}</p> : null}

        <div className="login-links">
          <Link to="/">Voltar</Link>
        </div>
      </form>
    </div>
  );
}
