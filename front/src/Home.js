import { Link } from "react-router-dom";
import "./Home.css";

export default function Home() {
  return (
    <div className="tela">
      <section className="cartao-inicial">
        <h1 className="titulo-inicial">Bem-vindo ao Quiz de PSPD!</h1>
        <p className="texto-inicial">Teste seus conhecimentos sobre PSPD.</p>
        <Link className="btn-reiniciar" to="/login">
          Login para começar o Quiz
        </Link>
      </section>
    </div>
  );
}
