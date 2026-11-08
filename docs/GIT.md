# Guia de Git do projeto

Leia até o fim antes do primeiro commit. São só 3 regras:

> 1. **Nunca trabalhe na `main`.** Cada pessoa trabalha na branch da sua parte.
> 2. **Só mexa nos arquivos da sua parte** (lista no [`DIVISAO.md`](DIVISAO.md)).
> 3. **Seu código só entra na `main` por pull request**, com outra pessoa do grupo aprovando.

---

## 1. Primeira vez (faz uma vez só)

Configure seu nome e e-mail (use o mesmo e-mail da sua conta do GitHub):

```bash
git config --global user.name "Seu Nome"
```

```bash
git config --global user.email "seu-email@exemplo.com"
```

Diga ao Git para juntar as mudanças com *merge* no `git pull`. Sem isso, as versões novas do Git dão erro de "divergent branches":

```bash
git config --global pull.rebase false
```

Baixe o repositório:

```bash
git clone https://github.com/ibiapleo/CPU_DE2-115.git
```

```bash
cd CPU_DE2-115
```

Crie a branch da sua parte (troque `parte-b` pela sua: `parte-a`, `parte-b`, `parte-c` ou `parte-d`):

```bash
git switch -c parte-b
```

Abra o projeto no Quartus pelo arquivo `projeto2.qpf`.

---

## 2. Todo dia, antes de começar

Confira em que branch você está:

```bash
git branch
```

A branch atual aparece com `*`. **Se for a `main`, troque para a sua antes de mexer em qualquer coisa:**

```bash
git switch parte-b
```

Traga as novidades que os outros já colocaram na `main`:

```bash
git pull origin main
```

---

## 3. Salvar seu trabalho (commit e push)

**Passo 1: veja o que mudou.**

```bash
git status
```

Confira se aparecem **só arquivos da sua parte**. Se aparecer arquivo de outra pessoa, ou o `projeto2.qsf` sem você ter mudado nada de propósito, veja a seção 6 antes de continuar.

**Passo 2: escolha os arquivos.** Adicione um por um, com o nome. Evite `git add .`.

```bash
git add rtl/decoder.v sim/tb_decoder.v
```

**Passo 3: crie o commit** com uma mensagem que diga o que você fez:

```bash
git commit -m "feat: implementa decoder e testbench"
```

**Passo 4: envie para o GitHub.** Na primeira vez:

```bash
git push -u origin parte-b
```

Nas próximas vezes, basta:

```bash
git push
```

Faça commits pequenos e frequentes (por exemplo, a cada etapa que funcionou). Assim, se algo quebrar, dá para voltar.

**Mensagens de commit:** comece com o tipo e diga o que mudou.
- `feat: implementa debounce do button_handler`
- `fix: corrige sinal do resultado na ALU`
- `test: adiciona testes de overflow no tb_module_alu`
- `docs: atualiza tabela de testes`

Mensagens como "ajustes", "aaa" ou "agora vai" não dizem nada para o resto do grupo.

---

## 4. Pull request: colocar sua parte na `main`

Quando o testbench da sua parte passar:

1. Traga as novidades da `main` (`git pull origin main`), confira se tudo ainda compila no Quartus e dê `git push`.
2. Abra o repositório no GitHub. Vai aparecer um aviso amarelo com o botão **Compare & pull request**. Se não aparecer, vá na aba **Pull requests → New pull request**.
3. Confira as branches: **base: `main`** ← **compare: `parte-b`** (a sua).
4. **Título:** o que a sua parte faz. Exemplo: `Parte B: decoder e máquina de estados da CPU`.
5. **Descrição:** o que foi feito, como você testou (que testbench rodou, se testou na placa) e o que ainda falta.
6. Em **Reviewers**, escolha alguém do grupo.
7. Clique em **Create pull request**.

**Quem revisa:**
- Olha a aba **Files changed**: só mudaram arquivos daquela parte? As portas continuam iguais às do `DIVISAO.md`?
- Pode comentar numa linha específica clicando no `+` ao lado dela.
- Se estiver tudo certo: **Review changes → Approve**. Se não: **Request changes**, explicando o que precisa mudar.

**Depois de aprovado:** quem abriu o PR clica em **Merge pull request → Confirm merge**.

**Precisa corrigir algo que o revisor pediu?** Não abra outro PR. É só fazer novos commits na mesma branch e dar `git push`: o PR se atualiza sozinho.

**Depois do merge,** continue na sua branch normalmente e traga a `main` atualizada:

```bash
git pull origin main
```

---

## 5. Conflitos

Um conflito acontece quando duas pessoas mudam as mesmas linhas do mesmo arquivo. Seguindo a regra 2, isso quase não acontece. Se aparecer `CONFLICT` depois de um `git pull`:

1. Rode `git status` para ver quais arquivos estão em conflito.
2. Abra o arquivo. O trecho em conflito aparece assim:
   ```
   <<<<<<< HEAD
   (a sua versão)
   =======
   (a versão que veio da main)
   >>>>>>> ...
   ```
3. Deixe o trecho como deve ficar e **apague as 3 linhas de marcação** (`<<<<<<<`, `=======` e `>>>>>>>`).
4. Salve e finalize:
   ```bash
   git add nome-do-arquivo
   ```
   ```bash
   git commit -m "fix: resolve conflito com a main"
   ```

**Se o conflito for no arquivo de outra pessoa ou você não entender, pare e chame a pessoa (ou o grupo).** Não escolha "qualquer versão" para se livrar do erro.

---

## 6. Cuidados com o Quartus

- **`projeto2.qsf`:** o Quartus às vezes altera esse arquivo sozinho só por abrir ou compilar o projeto. Se ele aparecer no `git status` e você **não** mudou nada de propósito (pinos, arquivos do projeto, configurações), descarte a mudança:
  ```bash
  git restore projeto2.qsf
  ```
  Mudanças de propósito no `.qsf` (adicionar um arquivo novo ao projeto, mexer em pinos) são combinadas com o grupo antes e vão num PR separado.
- **Arquivos gerados** (`db/`, `incremental_db/`, `output_files/`, `simulation/`, `work/`, `.qws`, `.sof`) **nunca vão para o GitHub.** O `.gitignore` já cuida disso; se algum aparecer no `git status`, não adicione.
- **Feche o Quartus antes de trocar de branch** (`git switch`). Senão, ele pode sobrescrever arquivos com a versão da outra branch.

---

## 7. Socorro

| Situação | O que fazer |
|---|---|
| Mexi em arquivos estando na `main` e **ainda não fiz commit** | `git switch parte-b`: as mudanças vão junto com você para a sua branch |
| **Fiz commit na `main`** por engano (e ainda não dei push) | `git branch parte-b` (se a branch ainda não existe) e depois `git reset --hard origin/main`. Se a branch já existe, peça ajuda antes |
| `git push` deu `rejected` | `git pull`, depois `git push` de novo |
| Quero desfazer as mudanças de um arquivo (que ainda não foram para commit) | `git restore nome-do-arquivo` |
| Quero ver o histórico | `git log --oneline` |
| Não sei em que estado está o repositório | `git status`: ele quase sempre diz o próximo comando |

**Nunca use `git push --force`** nem apague branch dos outros. Se o Git sugerir algo com `--force`, pare e pergunte no grupo.
