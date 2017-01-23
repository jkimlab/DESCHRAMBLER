#include <iostream>
#include <fstream>
#include <cstdlib>
#include <string>
#include <vector>
#include <sstream>
#include <map>
#include <algorithm>
#include <list>
#include <iomanip>
#include <cmath>

using namespace std;

enum {SUCCESS, FAIL, CYCLE}; 
const double gMaxScore = 1.0;
const double gMinScore = 0.0000001;
const double gDiffScore = gMaxScore - gMinScore;
double gAlpha = 0.5;
int gMinPEReads = 100;	
double gMinRelCov = 0.5;
bool gUseCov = false;
double gMIN_WEIGHT = 0.0;

class Edge {
public:
	int bid1, bid2;
	int dir1, dir2;
	double score1, score2, weight;

	Edge(int _bid1, int _dir1, int _bid2, int _dir2)
			:bid1(_bid1), dir1(_dir1), bid2(_bid2), dir2(_dir2), 
			score1(0.0), score2(0.0), weight(0.0) {}
	
	bool operator<(const Edge& p) const {
		if (bid1 == p.bid1 && dir1 == p.dir1 && bid2 == p.bid2) return dir2 < p.dir2;
		if (bid1 == p.bid1 && dir1 == p.dir1) return bid2 < p.bid2;
		if (bid1 == p.bid1) return dir1 < p.dir1;
		return bid1 < p.bid1;
	}

	void reverse() {
		int tmp = bid1;
		bid1 = bid2;
		bid2 = tmp;

		tmp = dir1;
		dir1 = dir2;
		dir2 = tmp;
		if (dir1 == 1) dir1 = -1;
		else dir1 = 1;
		if (dir2 == 1) dir2 = -1;
		else dir2 = 1;
	}

	string toString(map<int, string>& map2name) {
		string bname1 = map2name[bid1];
		string bname2 = map2name[bid2];
		string strdir1 = "+";
		if (dir1 == -1) { strdir1 = "-"; }
		string strdir2 = "+";
		if (dir2 == -1) { strdir2 = "-"; }
		stringstream ss;
		ss << bname1 << " " << strdir1 << "\t" << bname2 << " " << strdir2 << "\t";
		ss << fixed << setprecision(6) << weight << "\t" << score1 << "\t" << score2;
		return ss.str(); 
	}
};

double compute_weight(int bid1, int dir1, int bid2, int dir2, map<Edge,double>& mapscore1) 
{
	double adjscore = 0.0;
	map<Edge, double>::iterator bpiter1, bpiter2;
	map<Edge, int>::iterator iter;

	bpiter1 = mapscore1.find(Edge(bid1, dir1, bid2, dir2));
    if (bpiter1 != mapscore1.end()) adjscore = bpiter1->second;
	
	return adjscore;
}

void error (string msg, string file="") 
{
	cerr << msg << file << endl;
	exit(1);
}

bool cmp(const pair<Edge,double> &p1, const pair<Edge,double> &p2) 
{
	return p1.second > p2.second;
}

int insertEdge(list<Edge>& le, Edge& e, map<int,int>& mapUsed)
{
	Edge& fe = le.front();
	Edge& be = le.back();
	
	if (fe.bid1 == e.bid1 && fe.dir1 != e.dir1) {
		// check for a cycle
		if (be.bid2 == e.bid2 && be.dir2 != e.dir2) {
			return CYCLE; 
		}
		
		// e precedes fe with an opposite direction
		e.reverse();
		le.push_front(e);
		mapUsed[fe.bid1] = 1;
		mapUsed[-fe.bid1] = 1;
		if (e.dir1 == 1) mapUsed[-e.bid1] = 1;
		else mapUsed[e.bid1] = 1;
		return SUCCESS;	
	}
	if (fe.bid1 == e.bid2 && fe.dir1 == e.dir2) {
		if (fe.bid1 == 0) return FAIL;

		// check for a cycle
		if (be.bid2 == e.bid1 && be.dir2 == e.dir1) return CYCLE; 

		// e precedes fe with the same direction
		le.push_front(e);
		mapUsed[fe.bid1] = 1;
		mapUsed[-fe.bid1] = 1;
		if (e.dir1 == 1) mapUsed[-e.bid1] = 1;
		else mapUsed[e.bid1] = 1;
		return SUCCESS;
	}

	if (be.bid2 == e.bid1 && be.dir2 == e.dir1) {
		if (be.bid2 == 0) return FAIL;

		// check for a cycle
		if (fe.bid1 == e.bid2 && fe.dir1 == e.dir2) return CYCLE; 
		
		// be precedes e with the same direction
		le.push_back(e);
		mapUsed[be.bid2] = 1;
		mapUsed[-be.bid2] = 1;
		if (e.dir2 == 1) mapUsed[e.bid2] = 1;
		else mapUsed[-e.bid2] = 1;
		return SUCCESS;
	}
	if (be.bid2 == e.bid2 && be.dir2 != e.dir2) {
		// check for a cycle
		if (fe.bid1 == e.bid1 && fe.dir1 != e.dir1) return CYCLE; 
		
		// be precedes e with an opposite direction
		e.reverse();
		le.push_back(e);
		mapUsed[be.bid2] = 1;
		mapUsed[-be.bid2] = 1;
		if (e.dir2 == 1) mapUsed[e.bid2] = 1;
		else mapUsed[-e.bid2] = 1;
		return SUCCESS;	
	}
	return FAIL;
}
	
void printLists(int numblocks, map<int, list<Edge> >& mapClasses, char* anc_f, char* join_f)
{
	map<int, list<Edge> >::iterator citer;

	ofstream outf_anc;
	outf_anc.open(anc_f);
	ofstream outf_join;
	outf_join.open(join_f);

	outf_anc << ">ANCESTOR\t" << numblocks << endl;
	int clsnum = 1;	
	for(citer = mapClasses.begin(); citer != mapClasses.end(); citer++) {
		list<Edge>& le = citer->second;
		int listsize = le.size();
		outf_anc << "# APCF " << clsnum << endl;
		clsnum++;
	
		list<Edge>::iterator liter;
		int cnt = 0;
		for (liter = le.begin(); liter != le.end(); liter++) {
			Edge& e = *liter;
			if (cnt < listsize-1) { 
				if (e.bid1 != 0) outf_anc << e.bid1*e.dir1 << " ";
			} else { 
				if (e.bid1 != 0) outf_anc << e.bid1*e.dir1 << " ";
				if (e.bid2 != 0) outf_anc << e.bid2*e.dir2 << " $";
				else outf_anc << " $";
			}
			cnt++;

			outf_join << e.bid1*e.dir1 << "\t" << e.bid2*e.dir2 << "\t" << e.weight << endl; 
		}	
		outf_anc << endl;

	} // end of for
	outf_anc.close();	
	outf_join.close();
}

double computeAvg(map<Edge,double>& mapScores)
{
	map<Edge,double>::iterator iter;
	double sum = 0.0;
	int cnt = mapScores.size();
	for (iter = mapScores.begin(); iter != mapScores.end(); iter++) {
		sum += iter->second;
	}
	return (sum/cnt);
} 

void mergeLists(int clscnt, int clsid, list<Edge>& le, map<int, list<Edge> > &mapClasses) 
{
	map<int, list<Edge> >::iterator citer;
	list<Edge>::iterator liter;
	list<Edge>::reverse_iterator rliter;
	list<Edge>& le1 = le;
		
	for (int j = 1; j <= clscnt; j++) {
		if (j == clsid) continue;

		citer = mapClasses.find(j);
		if (citer == mapClasses.end()) continue;
		list<Edge>& le2 = citer->second;
			
		Edge& e1front = le1.front();
		Edge& e1back = le1.back();
		
		Edge& e2front = le2.front();
		Edge& e2back = le2.back();

		if(e1front.bid1 == e2front.bid1 && e1front.dir1 != e2front.dir1) {
			// check cycle
			if (e1back.bid2 == 0 || e2back.bid2 == 0 || e1back.bid2 != e2back.bid2) {	
				for (liter = le2.begin(); liter != le2.end(); liter++) {
					Edge e2 = *liter;
					e2.reverse();
					le1.push_front(e2);
				} // end of for
				mapClasses.erase(j);
			}
		} else if(e1front.bid1 == e2back.bid2 && e1front.dir1 == e2back.dir2) {
			// check cycle
			if (e1front.bid1 != 0 && 
				(e1back.bid2 == 0 || e2front.bid1 == 0 || e1back.bid2 != e2front.bid1)) {
				for (rliter = le2.rbegin(); rliter != le2.rend(); rliter++) {
					Edge e2 = *rliter;
					le1.push_front(e2);
				} // end of for
				mapClasses.erase(j);	
			}	
		} else if(e1back.bid2 == e2front.bid1 && e1back.dir2 == e2front.dir1) {
			// check cycle
			if (e1back.bid2 != 0 && 
				(e1front.bid1 == 0 || e2back.bid2 == 0 || e1front.bid1 != e2back.bid2)) {
				for (liter = le2.begin(); liter != le2.end(); liter++) {
					Edge e2 = *liter;
					le1.push_back(e2);
				} // end of for
				mapClasses.erase(j);	
			}	
		} else if(e1back.bid2 == e2back.bid2 && e1back.dir2 != e2back.dir2) {
			// check cycle
			if (e1front.bid1 == 0 || e2front.bid1 == 0 || e1front.bid1 != e2front.bid1) {
				for (rliter = le2.rbegin(); rliter != le2.rend(); rliter++) {
					Edge e2 = *rliter;
					e2.reverse();
					le1.push_back(e2);
				} // end of for
				mapClasses.erase(j);	
			}
		}	
	} // end of for j
}

int main(int argc, char* argv[]) 
{
	gMIN_WEIGHT = atof(argv[1]);
	char* fcons = argv[2];
	char* outfanc = argv[3];
	char* outfjoin = argv[4];
	map<Edge, double>::iterator bpiter;

	cerr << "Minimum weight = " << gMIN_WEIGHT << endl;
	cerr << "Conservation score file = " << fcons << endl;

	// read adjacency scores
	int numblocks = 0;
	map<Edge, double> mapAdjScores;
	ifstream infile;
	infile.open(fcons);
	if (!infile) error ("\n[ERROR] Unable to open file: ", fcons); 
	int bid1, bid2;
	double adjscore;
	while (infile >> bid1 >> bid2 >> adjscore) {
		int bindex1 = abs(bid1); 
		int bindex2 = abs(bid2); 
		int intdir1 = 1;
		if (bid1 < 0) intdir1 = -1; 
		int intdir2 = 1;
		if (bid2 < 0) intdir2 = -1; 
		Edge bpf(bindex1, intdir1, bindex2, intdir2);
		Edge bpr(bindex2, -intdir2, bindex1, -intdir1);
		mapAdjScores[bpf] = adjscore;
		mapAdjScores[bpr] = adjscore;
		
		if (abs(bid1) > numblocks) numblocks = abs(bid1);
		if (abs(bid2) > numblocks) numblocks = abs(bid2);
	}
	infile.close();	

	// compute edge weights
	map<Edge, double> mapWeights;
	double weight = 0.0;
	for (int i = 0; i <= numblocks; i++) {	
		for (int j = 0; j <= numblocks; j++) { 
			if (i == j) continue;

			weight = compute_weight(i,1,j,1,mapAdjScores);
			if (weight > 0.0) mapWeights[Edge(i,1,j,1)] = weight; 
			weight = compute_weight(i,1,j,-1,mapAdjScores);
			if (weight > 0.0) mapWeights[Edge(i,1,j,-1)] = weight; 
			weight = compute_weight(i,-1,j,1,mapAdjScores);
			if (weight > 0.0) mapWeights[Edge(i,-1,j,1)] = weight; 
			weight = compute_weight(i,-1,j,-1,mapAdjScores);
			if (weight > 0.0) mapWeights[Edge(i,-1,j,-1)] = weight; 
		} // end of j
	} // end of for

	// greedy search based on edge weights
	vector<pair<Edge,double> > vecEdges(mapWeights.begin(), mapWeights.end()); 
	sort (vecEdges.begin(), vecEdges.end(), cmp);

	map<int, int> mapUsed;	
	map<int, int>::iterator uiter, uiterex;
	map<int, list<Edge> > mapClasses;
	map<int, list<Edge> >::iterator citer;
	map<Edge, int>::iterator niter;
	map<Edge, double>::iterator biter;
	int clscnt = 0;
	for (int i = 0; i < vecEdges.size(); i++) {
		pair<Edge,double> p = vecEdges.at(i);
		Edge& e = p.first;
		e.weight = p.second;

		bpiter = mapAdjScores.find(e);
		if (bpiter != mapAdjScores.end()) e.score1 = mapAdjScores[e];
	
		if (e.weight < gMIN_WEIGHT) continue;

		if (e.bid1 != 0) {
			if (e.dir1 == 1) uiter = mapUsed.find(-e.bid1); 
			else uiter = mapUsed.find(e.bid1);  
			if (uiter != mapUsed.end()) continue; 
		}	
		
		if (e.bid2 != 0) {
			if (e.dir2 == 1) uiter = mapUsed.find(e.bid2);
			else uiter = mapUsed.find(-e.bid2); 
			if (uiter != mapUsed.end()) continue;
		}		

		bool found = false;
		for (citer = mapClasses.begin(); citer != mapClasses.end(); citer++) {
			list<Edge>& le = citer->second;
			int res = insertEdge(le, e, mapUsed);
			if (res == SUCCESS || res == CYCLE) { 
				if (res == SUCCESS) mergeLists(clscnt, citer->first, le, mapClasses);
				found = true;
				break;
			} // end of if	
		} // end of for 
	
		if (found == false) {
			list<Edge> le;
			le.push_back(e);
			mapClasses[++clscnt] = le;
		
			if (e.bid1 != 0) {	
				if (e.dir1 == 1) mapUsed[-e.bid1] = 1; 
				else mapUsed[e.bid1] = 1; 
			}
			if (e.bid2 != 0) {
				if (e.dir2 == 1) mapUsed[e.bid2] = 1; 
				else mapUsed[-e.bid2] = 1; 
			}
		}	
	}

	printLists(numblocks, mapClasses, outfanc, outfjoin);

	return 0;
}
