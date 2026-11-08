# Projeto 2 — Sistemas Digitais: Mini-CPU na DE2-115

Mini-CPU em Verilog com banco de 16 registradores de 16 bits, ALU e saída no LCD 16×2 da placa Terasic DE2-115 (Cyclone IV E `EP4CE115F29C7`). As instruções entram pelos 18 switches e são enviadas ao soltar o botão **Enviar** (`KEY0`); o botão **Ligar** (`KEY1`) liga e desliga o sistema.

## Documentação

| Documento | Conteúdo |
|---|---|
| [`docs/DIVISAO.md`](docs/DIVISAO.md) | **Comece por aqui.** As 4 partes, o diagrama de integração, o formato das instruções, os testes esperados e o que cada parte faz |
| [`docs/GIT.md`](docs/GIT.md) | Como trabalhar com Git no projeto: branch, commit, push e pull request |

## Estrutura

```
projeto2.qpf / projeto2.qsf   projeto do Quartus (na raiz)
rtl/                          código Verilog (um módulo por arquivo)
sim/                          testbenches (tb_<modulo>.v) e run.do (ModelSim)
docs/                         documentação
```

`module_mini_cpu.v`, `module_alu.v` e `memory.v` são os módulos obrigatórios do enunciado. Todos os módulos já existem com as **portas finais** e o corpo vazio (`TODO`), então o projeto compila desde o primeiro dia.

## Abrir e compilar (Quartus)

1. Clone o repositório e abra `projeto2.qpf` no Quartus.
2. *Processing → Start Compilation*.
3. *Tools → Programmer* → *Hardware Setup*: USB-Blaster → *Start* (arquivo `output_files/projeto2.sof`).

## Simular (ModelSim / Questa)

No console do simulador:

```
cd <pasta do repositorio>/sim
do run.do tb_module_alu
```

Troque `tb_module_alu` pelo testbench da sua parte.

## Usar na placa

1. Programe a placa: o LCD fica apagado (sistema desligado).
2. Solte **KEY1 (Ligar)**: aparece a tela inicial e os registradores são zerados.
3. Monte a instrução nos switches (`SW[17:15]` = opcode, ver `docs/DIVISAO.md`). Os LEDs vermelhos mostram os switches.
4. Solte **KEY0 (Enviar)**: o resultado aparece no LCD.
5. Solte **KEY1** de novo para desligar (LCD apaga e os registradores são zerados).

## Git

Branch principal: `main` (sempre compilando). Cada parte trabalha na sua branch (`parte-a`, `parte-b`, …) e entra na `main` por PR.
