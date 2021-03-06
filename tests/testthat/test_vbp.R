context("Value-based pricing")

test_that(
  "define value-based pricing", {
    vbp1 <- define_vbp(
      price, 10, 45
    )
    expect_identical(
      dim(vbp1$vbp),
      c(3L, 1L)
    )
    expect_is(
      vbp1$vbp$price,
      "list"
    )
    expect_s3_class(
      vbp1$vbp$price[[1]],
      "lazy"
    )
    expect_error(
      define_vbp(
        a, 10, 45, 
        b, 5, 10
      )
    )
    expect_error(
      define_vbp(
        a, 10, 45, 20
      )
    )
    expect_error(
      define_vbp(
        10, 45
      )
    )
    expect_error(
      define_vbp(
        C, 10, 45
      )
    )
  })

test_that(
  "run value-based pricing", {
    #### Define parameters ####
    param <- define_parameters(
      pA = 10000,
      cA = pA,
      cB = 2000, 
      cC = 100,
      qolDisabled  = .8,  #QoL of failing treatment
      pDieDisease  = 0.02,
      pDieDisabled = 0.03,
      costPerVisit = 5000, 
      cDisabled    = 5000,
      meanNumVisits_C = 2.8,
      meanNumVisits_A = 1,
      meanNumVisits_B = 2,
      pFailA = 0.15,
      pFailB = 0.2,
      pFailC = 0.3,
      dr = .05
    )
    #### Define transition probabilities ####
    ### Base Strategy
    mat_base <- define_transition(
      state_names = c("Disease", "Disabled", "Death"), 
      
      C, pFailC, pDieDisease,
      0, C,      pDieDisabled, 
      0, 0,      1)
    
    ### Medicine strategy
    mat_A <- define_transition(
      state_names = c("Disease", "Disabled", "Death"), 
      
      C, pFailA, pDieDisease,
      0, C,      pDieDisabled, 
      0, 0,      1)
    
    ### Surgery strategy
    mat_B <- define_transition(
      state_names = c("Disease", "Disabled", "Death"), 
      
      C, pFailB, pDieDisease,
      0, C,      pDieDisabled, 
      0, 0,      1)
    
    #### Define state rewards ####
    ## State PreSymptomatic (Pre)
    state_disease <- define_state(
      cost_treat = dispatch_strategy(
        base = cC, 
        A    = cA, 
        B    = cB), 
      cost_hospit = dispatch_strategy(
        base = meanNumVisits_C * costPerVisit,
        A    = meanNumVisits_A * costPerVisit, 
        B    = meanNumVisits_B * costPerVisit),
      cost_total = discount(cost_treat + cost_hospit, r = dr), 
      qaly = 1)
    
    ## State Symptomatic (Symp)
    state_disabled <- define_state(
      cost_treat = 0, 
      cost_hospit = cDisabled, 
      cost_total = discount(cost_treat + cost_hospit, r = dr), 
      qaly = qolDisabled)
    
    ## State Death (Death)
    state_death <- define_state(
      cost_treat = 0, 
      cost_hospit = 0, 
      cost_total = 0, 
      qaly = 0)
    
    #### Define strategies ####
    ### Base
    strat_base <- define_strategy(
      transition = mat_base, 
      Disease = state_disease, 
      Disabled = state_disabled, 
      Death = state_death)
    
    ### Medicine
    strat_A <- define_strategy(
      transition = mat_A, 
      Disease = state_disease, 
      Disabled = state_disabled, 
      Death = state_death)
    
    ### Surgery
    strat_B <- define_strategy(
      transition = mat_B, 
      Disease = state_disease, 
      Disabled = state_disabled, 
      Death = state_death)
    
    #### Run model ####
    res2 <- run_model(
      parameters = param, 
      base = strat_base, 
      A    = strat_A, 
      B    = strat_B, 
      cycles = 50, 
      cost = cost_total, 
      effect = qaly, 
      method = "life-table")
    
    res3 <- suppressWarnings(run_model(
      parameters = param, 
      base = strat_base, 
      A    = strat_A, 
      B    = strat_B, 
      cycles = 50
    ))
    
    #### Value-Based Pricing (VBP) analysis ####
    ### VBP on "A" strategy
    ## VBP on cA parameter
    def_vbp <- define_vbp(
      cA, 0, 20000
    )
    ## Run VBP
    expect_error(
      run_vbp(model = res2,
              vbp = def_vbp,
              wtp_thresholds = c(0, 50000))
    )
    expect_error(
      run_vbp(model = res2,
              vbp = def_vbp,
              strategy_vbp = "A")
    )
    
    x <- run_vbp(model = res2,
                 vbp = def_vbp,
                 strategy_vbp = "A",
                 wtp_thresholds = c(0, 50000))
    
    expect_equal(
      round(x$vbp$Price[c(1, 10, 20, 30,
                          40, 50, 60, 100)]),
      c(4694, 5813, 6558, 7155,
        7752, 8349, 8945, 11333)
    )
    
    expect_error(run_vbp(res3, def_vbp))
    
    plot(x)
    plot(x, bw = TRUE)
    
    #### VBP of parameter not affecting selected strategy ####
    ## VBP on cB parameter and strategy A
    def_vbp <- define_vbp(
      cB, 0, 20000
    )
    ## Run VBP
    expect_error(
      run_vbp(model = res2,
              vbp = def_vbp,
              strategy_vbp = "A",
              wtp_thresholds = c(0, 50000))
    )
    
    #### Test non-linearity ####
    def_vbp <- define_vbp(
      pA, 1, 20000
    )
    
    param_log <- modify(
      param,
      cA = log(pA)
    )
    
    res4 <- run_model(
      parameters = param_log, 
      base = strat_base, 
      A    = strat_A, 
      B    = strat_B, 
      cycles = 50, 
      cost = cost_total, 
      effect = qaly, 
      method = "life-table")
    
    x <- run_vbp(model = res4,
                 vbp = def_vbp,
                 strategy_vbp = "A",
                 wtp_thresholds = c(0, 50000))
    
    expect_equal(
      as.numeric(unlist(x$lin_approx)),
      c(0, 1, 0)
    )
    
    #### Price affecting multiple strategies ####
    param <- modify(
      param,
      cA = pA,
      cB = pA
    )
    
    res5 <- run_model(
      parameters = param, 
      base = strat_base, 
      A    = strat_A, 
      B    = strat_B, 
      cycles = 50, 
      cost = cost_total, 
      effect = qaly, 
      method = "life-table")
    
    x <- run_vbp(model = res5,
                 vbp = def_vbp,
                 strategy_vbp = "A",
                 wtp_thresholds = c(0, 50000))
    plot(x)
    
    x <- run_vbp(model = res5,
                 vbp = def_vbp,
                 strategy_vbp = "B",
                 wtp_thresholds = c(0, 50000))
    plot(x)
  })