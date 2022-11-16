grep "Total Power:" power.rpt | awk '{print "Total Power: " $3 " mW"}' > design_cost.rpt
grep "ALL" timing.rpt | awk '{print "WNS for setup: " $4 " ps"}' >> design_cost.rpt
grep "ALL" timing.rpt | awk '{print "TNS for setup: " $5 " ps"}' >> design_cost.rpt
grep "ALL" timing.rpt | awk '{print "Failing endpoints for setup: " $6}' >> design_cost.rpt
grep "." area.rpt | awk '{print "Die area: " $0 " sq.um"}' >> design_cost.rpt
