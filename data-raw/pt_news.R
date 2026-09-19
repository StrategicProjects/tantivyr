# Builds the `pt_news` example dataset.
#
# The items are short, fictional news stories written for this package, so they
# carry no third-party copyright. Run from the package root:
#   Rscript data-raw/pt_news.R

items <- list(
  # economia
  list("economia", "2024-01-15", "Inflação desacelera e fecha o ano abaixo da meta",
       "Os preços dos alimentos caíram pelo terceiro mês seguido. Economistas esperam que o banco central reduza os juros nas próximas reuniões."),
  list("economia", "2024-02-03", "Banco central reduz a taxa de juros pela quarta vez",
       "A decisão foi unânime entre os diretores. O mercado já esperava a redução, e a bolsa fechou o dia em alta."),
  list("economia", "2024-03-21", "Exportações de café batem recorde no primeiro trimestre",
       "Os produtores exportaram mais de dez milhões de sacas. A valorização do produto no mercado externo compensou a quebra da safra."),
  list("economia", "2024-05-09", "Desemprego recua e atinge o menor nível em dez anos",
       "O setor de serviços foi o que mais contratou trabalhadores. Os salários, porém, cresceram menos do que a inflação do período."),
  list("economia", "2024-08-27", "Governo anuncia novo programa de crédito para pequenas empresas",
       "As empresas poderão financiar máquinas e equipamentos com juros reduzidos. O programa deve beneficiar cerca de duzentos mil empreendedores."),
  list("economia", "2025-02-11", "Orçamento municipal prioriza obras de saneamento",
       "A câmara aprovou o orçamento com folga. Os vereadores destinaram a maior parte dos recursos para redes de esgoto e abastecimento de água."),
  # saude
  list("saúde", "2024-01-28", "Campanha de vacinação contra a gripe começa na segunda-feira",
       "Idosos e crianças serão vacinados primeiro. A secretaria de saúde recebeu dois milhões de doses da vacina."),
  list("saúde", "2024-04-02", "Casos de dengue aumentam e municípios decretam emergência",
       "Os hospitais registraram o dobro de internações em relação ao ano passado. Agentes de saúde visitam as casas para eliminar focos do mosquito."),
  list("saúde", "2024-06-18", "Hospital universitário inaugura centro de transplantes",
       "O centro realizará transplantes de rim e de fígado. A fila de espera por um órgão no estado tem mais de três mil pacientes."),
  list("saúde", "2024-09-30", "Pesquisadores testam nova vacina contra a dengue",
       "A pesquisa envolve cinco mil voluntários em quatro capitais. Os primeiros resultados devem ser publicados no próximo ano."),
  list("saúde", "2025-01-20", "Médicos alertam para o aumento da obesidade infantil",
       "Uma em cada três crianças está acima do peso. Os médicos recomendam reduzir o consumo de alimentos ultraprocessados."),
  list("saúde", "2025-03-14", "Estado amplia o atendimento por telemedicina no interior",
       "Pacientes de cidades pequenas poderão consultar especialistas por vídeo. A medida deve reduzir as viagens até os hospitais da capital."),
  # educacao
  list("educação", "2024-02-19", "Escolas públicas voltam às aulas com novos laboratórios",
       "Os alunos terão aulas práticas de ciências e de robótica. Cada escola recebeu computadores e acesso à internet de alta velocidade."),
  list("educação", "2024-04-25", "Universidade abre mil vagas em cursos noturnos",
       "As vagas são destinadas a estudantes que trabalham durante o dia. As inscrições podem ser feitas pela internet até o fim do mês."),
  list("educação", "2024-07-08", "Professores aprovam greve por reajuste salarial",
       "A categoria pede reposição das perdas com a inflação. O governo afirma que não há espaço no orçamento para o reajuste pedido."),
  list("educação", "2024-10-16", "Estudantes brasileiros conquistam medalhas em olimpíada de matemática",
       "A equipe voltou com duas medalhas de ouro e uma de prata. Os estudantes treinaram durante seis meses com professores voluntários."),
  list("educação", "2025-02-27", "Programa de alfabetização de adultos chega a cem municípios",
       "As aulas acontecem à noite em escolas e associações de bairro. Mais de vinte mil adultos já aprenderam a ler com o programa."),
  list("educação", "2025-04-05", "Biblioteca municipal digitaliza acervo de jornais antigos",
       "Os leitores poderão pesquisar o texto de jornais publicados desde 1890. A digitalização preserva exemplares que estavam se deteriorando."),
  # tecnologia
  list("tecnologia", "2024-01-09", "Startup recifense cria aplicativo para monitorar enchentes",
       "O aplicativo avisa os moradores quando o nível dos rios sobe. Os dados vêm de sensores instalados em pontes e canais da cidade."),
  list("tecnologia", "2024-03-12", "Operadoras ampliam a cobertura de internet móvel na zona rural",
       "Mais de trezentas comunidades rurais receberam antenas novas. Os agricultores usam a conexão para acompanhar preços e previsão do tempo."),
  list("tecnologia", "2024-06-04", "Pesquisadores desenvolvem bateria que carrega em cinco minutos",
       "A bateria usa um material mais barato do que o lítio. O grupo de pesquisa busca parceiros para produzir o equipamento em escala industrial."),
  list("tecnologia", "2024-09-17", "Prefeitura adota inteligência artificial para organizar o trânsito",
       "Os semáforos ajustam o tempo de abertura conforme o fluxo de veículos. Nos primeiros testes, o tempo de viagem caiu quinze por cento."),
  list("tecnologia", "2024-11-22", "Ataque cibernético tira do ar sistemas de um tribunal",
       "Os processos eletrônicos ficaram indisponíveis por dois dias. Especialistas em segurança investigam como os invasores acessaram a rede."),
  list("tecnologia", "2025-03-03", "Satélite brasileiro de monitoramento é lançado com sucesso",
       "O satélite vai monitorar o desmatamento e as queimadas. As imagens serão distribuídas gratuitamente para pesquisadores e órgãos ambientais."),
  # meio ambiente
  list("meio ambiente", "2024-02-14", "Desmatamento na Amazônia cai pelo segundo ano consecutivo",
       "A área desmatada foi a menor desde o início do monitoramento por satélite. A fiscalização aplicou multas a mais de mil propriedades."),
  list("meio ambiente", "2024-05-23", "Seca prolongada reduz o nível dos reservatórios",
       "Os reservatórios operam com menos de um terço da capacidade. As cidades da região já adotam o rodízio no abastecimento de água."),
  list("meio ambiente", "2024-07-30", "Queimadas atingem áreas de preservação no cerrado",
       "Os bombeiros combatem o fogo há uma semana. A fumaça das queimadas prejudicou a qualidade do ar em várias cidades."),
  list("meio ambiente", "2024-10-05", "Projeto recupera nascentes e devolve água a um rio seco",
       "Agricultores plantaram cem mil mudas de árvores nativas nas margens. Depois de três anos, o rio voltou a correr durante todo o ano."),
  list("meio ambiente", "2025-01-08", "Chuvas fortes causam enchentes e deslizamentos no litoral",
       "Mais de duas mil famílias deixaram suas casas. A defesa civil monitora as encostas e mantém abrigos abertos nas escolas."),
  list("meio ambiente", "2025-04-22", "Usina solar flutuante começa a operar em reservatório",
       "Os painéis solares flutuam sobre a água e reduzem a evaporação. A usina gera energia suficiente para abastecer trinta mil casas."),
  # esporte
  list("esporte", "2024-03-05", "Seleção feminina de futebol vence e garante vaga na final",
       "As jogadoras venceram por dois gols a zero diante de um estádio lotado. A final será disputada no próximo domingo."),
  list("esporte", "2024-05-30", "Maratonista pernambucana quebra o recorde nacional",
       "A atleta completou a maratona em pouco mais de duas horas e vinte minutos. Ela treinou na altitude durante três meses."),
  list("esporte", "2024-08-11", "Brasil conquista o ouro no vôlei de praia",
       "A dupla brasileira venceu a final em dois sets. É a terceira medalha de ouro do país na modalidade."),
  list("esporte", "2024-10-28", "Clube centenário inaugura estádio reformado",
       "O estádio ganhou cobertura nova e capacidade para quarenta mil torcedores. A reforma durou dois anos e foi financiada pelos sócios."),
  list("esporte", "2025-02-02", "Nadador de dezessete anos vence campeonato sul-americano",
       "O jovem nadador venceu três provas e bateu o recorde do campeonato. Ele começou a nadar em um projeto social da sua cidade."),
  list("esporte", "2025-04-13", "Corrida de rua reúne vinte mil atletas no centro da cidade",
       "Os corredores percorreram dez quilômetros por avenidas fechadas ao trânsito. A renda das inscrições foi doada a hospitais infantis.")
)

pt_news <- tibble::tibble(
  id      = seq_along(items),
  section = vapply(items, `[[`, character(1), 1L),
  date    = as.Date(vapply(items, `[[`, character(1), 2L)),
  title   = vapply(items, `[[`, character(1), 3L),
  body    = vapply(items, `[[`, character(1), 4L)
)
pt_news <- pt_news[order(pt_news$date), ]
pt_news$id <- seq_len(nrow(pt_news))

for (col in c("section", "title", "body")) {
  pt_news[[col]] <- enc2utf8(pt_news[[col]])
}

save(pt_news, file = "data/pt_news.rda", compress = "xz", version = 2)
