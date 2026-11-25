# Experimentos Git sobre SSH com troca de chaves clássica e pós-quântica

Este repositório contém o script e os resultados dos experimentos do Trabalho de Conclusão de Curso
"[título do TCC]", desenvolvido por Milene Vargas no curso de [nome do curso] do IFFar,
campus Frederico Westphalen, em 2026.

Os experimentos compararam o desempenho das operações `clone`, `pull` e `push` do Git realizadas
via SSH utilizando dois algoritmos de troca de chaves:

- **Clássico:** `curve25519-sha256`
- **Pós-quântico:** `mlkem768-sha256`

## Ambiente

- 3 máquinas virtuais (1 cliente e 2 servidores) no VirtualBox 7.2.16
- Ubuntu Server 26.04.1 LTS, 2 vCPUs, 4 GB de RAM e 30 GB de disco
- OQS-OpenSSH 2026-05 (fork do OpenSSH 10.3), liboqs 0.16.0 e OpenSSL 3.5.5
- Git 2.53.0
- Repositório utilizado nos testes: Flask

## Arquivos

| Arquivo | Descrição |
|---|---|
| `experimento_git.sh` | Script Bash que automatiza a execução das operações e a coleta das métricas |
| `resultados_git.csv` | Resultados de cada uma das 180 execuções |

## Como o experimento funciona

Cada operação foi executada 30 vezes em cada cenário, em uma ordem definida previamente no script.
Nas operações de pull e push, o commit com um arquivo aleatório de 200 KB é preparado antes da
medição, e apenas o comando Git é cronometrado. Ao final de cada operação, o script confere se o
commit recebido é o esperado e se o arquivo transferido é idêntico ao original, pelo hash SHA-256.

## Colunas do arquivo de resultados

| Coluna | Descrição |
|---|---|
| `ordem` | Posição da operação na sequência predefinida (1 a 180) |
| `operacao` | Operação Git executada (`clone`, `pull` ou `push`) |
| `cenario` | Algoritmo de troca de chaves (`classico` ou `pqc`) |
| `repeticao` | Número da repetição (001 a 030) |
| `pasta` | Pasta do repositório onde o arquivo foi adicionado (pull e push) |
| `tempo_ms` | Tempo de execução da operação, em milissegundos |
| `status` | Resultado da operação |
| `commit` | Hash do commit recebido ou enviado |
| `sha256` | Hash SHA-256 do arquivo transferido (pull e push) |
| `inicio_utc` | Data e hora de início da operação (UTC) |
| `cpu_percentual` | Uso de CPU do processo Git, medido com o GNU time |
| `memoria_max_kb` | Pico de memória do processo Git (KB), medido com o GNU time |
| `rx_bytes` | Bytes recebidos pela interface de rede do cliente |
| `tx_bytes` | Bytes transmitidos pela interface de rede do cliente |

## Como executar

    bash experimento_git.sh simular    # mostra a ordem das operações, sem executar nada
    bash experimento_git.sh executar   # executa as 180 operações

O script foi escrito para o ambiente descrito acima. Para executá-lo em outro ambiente, é necessário
ajustar os endereços IP, os caminhos dos repositórios e a chave SSH definidos no início do arquivo.
