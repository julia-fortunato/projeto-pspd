from locust import HttpUser, task, between
import random
import string




def random_string(n=8):
    return "".join(random.choices(string.ascii_lowercase + string.digits, k=n))




class QuizUser(HttpUser):
    wait_time = between(1, 3) 

    def on_start(self):
        self.login_name = f"locust_{random_string(6)}"
        self.password = "senha123"
        self.nome = f"User {self.login_name}"
        self.tokenrem = None

        self._create_user()
        self._login()


    def _create_user(self):
        payload = {
            "nome": self.nome,
            "login": self.login_name,
            "senha": self.password,
        }

        with self.client.post(
            "/grpc/user",
            json=payload,
            name="CreateUser",
            catch_response=True,
        ) as resp:
            if resp.status_code != 200:
                resp.failure(f"Falha ao criar usuário: {resp.status_code} {resp.text}")
            else:
                resp.success()

    def _login(self):
        payload = {
            "loginreq": self.login_name,
            "senhareq": self.password,
        }

        with self.client.post(
            "/grpc/login",
            json=payload,
            name="Login",
            catch_response=True,
        ) as resp:
            if resp.status_code != 200:
                resp.failure(f"Falha ao fazer login: {resp.status_code} {resp.text}")
                return

            try:
                data = resp.json()
                self.tokenrem = data.get("tokenrem")
                if not self.tokenrem:
                    resp.failure("Login OK, mas não veio 'tokenrem' no JSON")
                else:
                    resp.success()
            except Exception as e:
                resp.failure(f"JSON inválido em /grpc/login: {e}")

    @task(5)
    def get_quiz(self):
        self.client.get("/grpc/quiz", name="GetQuiz")

    @task(3)
    def atualizar_score_e_ver_ranking(self):
        if not self.tokenrem:
            return

        score = random.randint(0, 100)
        score_payload = {
            "scorenew": score,
            "remembertok": self.tokenrem,
        }

        self.client.post(
            "/grpc/user/score",
            json=score_payload,
            name="UpdateScore",
        )

        self.client.get(
            "/grpc/ranking",
            name="GetRanking",
        )

    @task(1)
    def criar_pergunta(self):
        idx_correto = random.randint(0, 3)
        payload = {
            "texto": f"Pergunta de carga {random_string(4)}?",
            "alternativas": [
                "Alt A",
                "Alt B",
                "Alt C",
                "Alt D",
            ],
            "indice_resposta": idx_correto,
            "explicacao": "Pergunta criada pelo Locust para teste de carga.",
        }

        self.client.post(
            "/grpc/quiz",
            json=payload,
            name="CreatePergunta",
        )

