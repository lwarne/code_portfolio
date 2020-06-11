import yaml
import numpy as np
import sys
import matplotlib.pyplot as plt
from mpl_toolkits.mplot3d import Axes3D
from itertools import product
import pandas as pd

if __name__ == '__main__':
    
    if len(sys.argv) <=1:
        print("Usage: python3 graph3D.py [output_file] ")
        sys.exit(0)
    else: 
         infile = sys.argv[1]

    with open(infile, 'r') as f:
        dic = yaml.load(f)
        #dic = yaml.unsafe_load(f)


    ##get from file
    #experiment set up
    num_rounds_list = dic['rounds']
    prods_per_round_list = dic["prods_count"]
    #loss
    loss = dic["results"]
    #accuracy (top 1 recall)
    model_acc = dic['model_acc']
    oracle_acc = dic['oracle_acc']
    train_accuracy = dic['train_accuracy']
    #mean reciprocal rank
    mean_recp_rank = dic['mean_recp_rank']
    oracle_mean_recp_rank = dic['oracle_mean_recp_rank']

    ## TAKE MEANS
    #take mean in Z
    mean_loss = np.mean(loss, axis=2)
    mean_model_acc = np.mean(model_acc, axis=2)
    avg_recp_rank = np.mean(mean_recp_rank, axis=2)
    mean_train_acc = np.mean(train_accuracy,axis = 2)

    ####### make plots and print them #######

    #convert to 3D format
    experiment_setup = product(num_rounds_list, prods_per_round_list)

    ## WORK WITH ACCURACY
    #take mean in Z
    mean_model_acc = np.mean(model_acc, axis=2)

    #convert to 3D format
    experiment_setup = product(num_rounds_list, prods_per_round_list)
    row = list()
    col = list()
    acc = list()
    diff = list()

    for x in experiment_setup:
        row.append(np.log10(x[0]))
        col.append(x[1])
        m = mean_model_acc[ num_rounds_list.index(x[0]) , prods_per_round_list.index(x[1]) ]
        o = oracle_acc[ num_rounds_list.index(x[0]) , prods_per_round_list.index(x[1]) ] 
        acc.append( m )
        diff.append( o-m )
        #print("row {} col {} m:{} o:{} m-o{}".format(x[0],x[1],m,o,m-o))

    #Plot model accuracy
    fig2 = plt.figure(2)
    fig2.set_size_inches(5, 5)
    #plt.xscale("log")
    ax = fig2.gca(projection='3d')
    ax.view_init(30, 110)
    ax.plot_trisurf( row, 
                    col,
                    acc , cmap=plt.cm.viridis, linewidth=0.2)

    #label axes
    lf=10
    plt.title("Top 1 Recall")
    ax.set_zlabel('Top 1 Recall', fontsize=lf, rotation = 0)
    ax.set_xlabel('Log 10 Rounds', fontsize=lf, rotation = 0)
    ax.set_xticks([1,2,3], minor=False)
    ax.set_ylabel('Products in Rounds', fontsize=lf, rotation = 0)
    ax.set_yticks([2,3,5,10], minor=False)
    plt.tight_layout()
    plt.savefig("SM_Recall.eps", format='eps')  

    #plot oracle - model accuracy
    fig2 = plt.figure(3)
    fig2.set_size_inches(5, 5)
    ax = fig2.gca(projection='3d')
    ax.view_init(30, 110)
    ax.plot_trisurf( row, 
                    col,
                    diff , cmap=plt.cm.viridis, linewidth=0.2)
    #label axes
    lf=10
    plt.title("Top 1 Recall, (Oracle - Model)")
    ax.set_zlabel('Recall Difference', fontsize=lf, rotation = 0)
    ax.set_xlabel('Log 10 Rounds', fontsize=lf, rotation = 0)
    ax.set_xticks([1,2,3], minor=False)
    ax.set_ylabel('Products in Rounds', fontsize=lf, rotation = 0)
    ax.set_yticks([2,3,5,10], minor=False)
    plt.tight_layout()
    plt.savefig("SM_Recall_diff.eps", format='eps')  


    plt.show()